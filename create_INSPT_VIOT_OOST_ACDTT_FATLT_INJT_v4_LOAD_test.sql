USE [Staging]
GO
/****** Object:  StoredProcedure [dbo].[create_INSPT_VIOT_OOST_ACDTT_FATLT_INJT]    Script Date: 8/5/2019 10:53:31 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kate Fisher
-- Create date: 2019-August
-- Description:	create INSPT, VIOT, OOST, ACDTT, FATLT, INJT tickers (ratios per 1000 tractors in a given fleet) for Aug2019 onward
-- =============================================
ALTER PROCEDURE [dbo].[create_INSPT_VIOT_OOST_ACDTT_FATLT_INJT]

	@datetouse DATE = '', -- EC: Set datetouse as a parameter, that way an alternate date can be used without altering code. 
	@MaxDate DATE = '' -- EC: Set datetouse as a parameter, that way an alternate date can be used without altering code.
AS

BEGIN
/*
assumptions for Aug2018-onward:
0. parent-child relationship table is updated every month and assuming logic is correct
1. the denominators (count of tractors) are from the monthly census_pub (so change over time). (to count towards the tickers, the DOT_numbers(fleets) must have tractors and mileage >1. )
2. the numerators belong to any fleets in the denominators (must have tractors and must have mileage >1 at any point from Aug2018 onward)
3. for duplicate crash or inspection IDs, then take the latest change_date.
4. the denominators for August, Sept, Oct, Nov, Dec are from the file census transfers from that month (Oct uses Sept/nov average), even though the dates are slightly off. But moving forward the transfers are all the 9th of the month
5. using the previous month, even those lots of records missing, so 6-1 months ago will be populated every time (1 month lag, but latest date still won't be super accurate)

*/

--decide how far back in the past we should delete and re-populate (4 months)
-- data should be a ninth of that month once data comes in regularly

	--declare @datetouse DATE = '' --uncomment for testing
	SET @datetouse = (SELECT CASE
								WHEN @datetouse = '1900-01-01' THEN dateadd(month, -4,max(data_timestamp)) 
								ELSE @datetouse
							 END as date_to_use
					  FROM Staging.dbo.indx_index_data
					  WHERE index_id BETWEEN 1047 AND 1052) -- EC: If no date is provided, query indx_index_data to get the max timestamp minus 5 months, else use provided date
	--select @datetouse

-- get the last of the month for the latest inspection record in the most recent transfer of data (sometimes earlier than expected) - 11-5-2019 KF
	--declare @MaxDate DATE = '' --uncomment for testing
	SET @MaxDate= (SELECT CASE
								WHEN @MaxDate = '1900-01-01' THEN DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0,MAX(CONVERT(DATE, CAST(INSP_DATE AS VARCHAR)))), 0))
								ELSE @MaxDate
							 END as max_date
					FROM warehouse.dbo.FMCSA_Insp_Load)-- Using LOAD until all the data will be read into the main ones (for now each month's transfer starting Nov 2019 will go into the Load)
	--select @MaxDate

--	select @MaxDate 
	--= DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0,MAX(CONVERT(DATE, CAST(INSP_DATE AS VARCHAR)))), 0))
	--FROM warehouse.dbo.FMCSA_Insp_Load
	--select @MaxDate 


---------------------
--> Main datasets <--
---------------------

--get mileage and number of tractors- each line a DOT_Number and asofdate. only selecting those in parent_child:
	DROP TABLE IF EXISTS #t1;--needed later for getting inspections/crashes just for these DOT_numbers
	SELECT a.DOT_number, 
		   CAST(mlg150 AS FLOAT) AS miles, 
		   cast(createdate as date) as asofdate, 
		   (CAST([OwnTract] AS INT) + CAST([TRMTract] AS INT) + CAST([TRPTract] AS INT)) AS tot_tract, 
		   b.stock_ticker,
		   DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0,createdate), 0)) as summary_date -- the 9th day
	INTO #t1
	FROM Warehouse.dbo.FMCSA_Census a --each month's transfer MUST be put in FMCSA_Census and NOT the _Load table
		 INNER JOIN (select distinct dot_number, stock_ticker
					 from warehouse.dbo.FMCSA_census_parent_child) b ON a.DOT_number = b.DOT_number
	WHERE act_stat = 'A'
		  AND (CAST([OWNTRACT] AS INT) > 0
			   OR CAST([TRPTRACT] AS INT) > 0
			   OR CAST([TRMTRACT] AS INT) > 0)
		  AND CAST(mlg150 AS FLOAT) > 1-- apply same criteria. must have tractor. reported mileage must be >1 
		  AND CAST(createdate as date) >= @datetouse

-- sum number of tractors by stock ticker and asofdate
-- converts it to the 9th of the month regardless of when file comes in 
	DROP TABLE IF EXISTS #tract
	SELECT stock_ticker, 
		   summary_date AS asofdate, --9th of month
		   SUM(tot_tract) AS tractors, 
		   COUNT(DISTINCT(DOT_number)) AS n_DOT_numbers
	INTO #tract
	FROM #t1
	GROUP BY Stock_Ticker, 
			 summary_date;

-- get records/variables of interest from  warehouse.dbo.FMCSA_Insp

	DROP TABLE IF EXISTS #all;
	SELECT distinct 
		   a.inspection_id, 
		   a.dot_number, 
		   a.report_state, 
		   CAST(insp_date AS DATE) AS insp_date, -- for inspections ticker
		   CONVERT(NUMERIC, viol_total) AS violations, -- for violations ticker
		   CONVERT(NUMERIC, OOS_total)  AS OOS_total, -- for Out of Service Violations ticker
		   CAST(upload_date AS DATE) AS upload_date, -- upload date
		   CAST(change_date AS DATE) AS change_date, -- change date- use for duplicate inspection_ids?
		   CAST(SNET_INPUT_DATE as DATE) as SNET_INPUT_DATE, --The date the inspection was input into SAFETYNET.
		   --assign to 9th of month for respective interval
		   CASE WHEN DATEPART(day, CAST(insp_date AS DATE)) <=9 THEN DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0, CAST(insp_date AS DATE)), 0))
		   ELSE DATEADD(mm,1,DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0, CAST(insp_date AS DATE)), 0))) END AS summary_date
	INTO #all
	FROM warehouse.dbo.FMCSA_Insp_LOAD a -- TEMPORARILY USING LOAD!!!!!!!!!!!!!!!!
		 INNER JOIN (select distinct dot_number 
					 from #t1) b -- this is filtered on the mileage and having tractors, and must be a part of the census_parent_child
		 ON a.DOT_NUMBER = b.DOT_NUMBER
	WHERE report_state IN('AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY')
	and CAST(insp_date AS DATE)>= DATEADD(MONTH,-1,DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0,@datetouse), 0)))
	--and CAST(insp_date AS DATE) <= DATEADD(mm,-1,DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0, getdate()), 0))) ;-- must happen in US and be in the last 7 months from last entry and the month before since it'll be an artificial drop off after
	and CONVERT(DATE, CAST(insp_date AS VARCHAR)) <=  @MaxDate ; --get the month before as latest since data isn't all in yet for the month;-- must happen in US and be in the last 7 months from last entry

	--select distinct (summary_date)
	--from #all

	-- cte to remove duplicate inspection_id
	;WITH dedup as (
		SELECT *,
			   ROW_NUMBER() OVER (PARTITION BY inspection_id ORDER BY change_date DESC) as RN
		FROM #all
	)
	DELETE
	FROM dedup
	WHERE RN > 1 or summary_date = @MaxDate

	--select count(distinct(INSPECTION_ID))
	--from #all

	--select count(*)
	--from #all


-- get records/variables of interest from warehouse.dbo.FMCSA_Crash_Master

	DROP TABLE IF EXISTS #allc;
	SELECT a.CRASH_ID, 
		   a.dot_number, 
		   a.report_state, 
		   cast(REPORT_DATE as date) as REPORT_DATE, -- report date
		   cast(FATALITIES as int) as FATALITIES, -- for fatalities
		   cast(INJURIES as int) as INJURIES, -- for injuries
		   cast(ADD_DATE as date) as ADD_DATE, -- add date
		   cast(UPLOAD_DATE as date) as UPLOAD_DATE, -- upload date
		   cast(CHANGE_DATE as date) as CHANGE_DATE, -- change date - use for duplicates- take latest
		   --assign to 9th of month for respective interval
		   CASE WHEN DATEPART(day, CAST(REPORT_DATE AS DATE)) <=9 THEN DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0, CAST(REPORT_DATE AS DATE)), 0))
		   ELSE DATEADD(mm,1,DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0, CAST(REPORT_DATE AS DATE)), 0))) END AS summary_date
	INTO #allc
	FROM warehouse.dbo.FMCSA_Crash_Master_LOAD a --TEMPORARILY USE LOAD !!!!!!!!!!!!!!!!!!!!!!!!!!!!
		 INNER JOIN (select distinct dot_number 
					 from #t1) b -- this is filtered on the mileage and having tractors, and must be a part of the census_parent_child
		 ON a.DOT_NUMBER = b.DOT_NUMBER
	WHERE report_state IN('AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY')-- must happen in US
		and CAST(REPORT_DATE AS DATE)>= DATEADD(MONTH,-1,DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0,@datetouse), 0)))
		--and CAST(REPORT_DATE AS DATE) <= DATEADD(mm,-1,DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0, getdate()), 0)))		; -- must happen in US and be in the last 6 months from last entry
		and CONVERT(DATE, CAST(report_date AS VARCHAR)) <=  @MaxDate ;

	-- cte to remove duplicate inspection_id
	;WITH dedup as (
		SELECT *,
			   ROW_NUMBER() OVER (PARTITION BY crash_id ORDER BY change_date DESC) as RN
		FROM #allc
	)
	DELETE
	FROM dedup
	WHERE RN > 1 or summary_date = @MaxDate

	--select count(distinct(crash_ID))
	--from #allc

	--select count(*)
	--from #allc


--  -- left join to make sure we have all these - date, stock_ticker, add granularity_item_id (inspections data has all combinations- in 100s)
	DROP TABLE IF EXISTS #combos;

	SELECT a.summary_date , b.stock_ticker, b.granularity_item_id
	INTO #combos
	FROM ( SELECT DISTINCT 
				  summary_date
		   FROM #all
		 ) AS a CROSS JOIN (SELECT	d.stock_ticker,
									c.id as granularity_item_id 
							FROM( SELECT DISTINCT 
									stock_ticker
							 FROM Warehouse.dbo.FMCSA_census_parent_child) d
							 INNER JOIN
								(
									SELECT *
									FROM staging.dbo.indx_granularity_item
									WHERE granularity_level_id = 19
								) c ON d.stock_ticker = c.granularity1) b
/*
select top (100)*
from #combos
order by summary_date desc
*/
---------------
---> INSPT <---
---------------

 --1047	Inspections per 1000 Tractors					INSPT	M	RATIO	Monthly Ratio of Inspections to 1000 Tractors 
 --sum inspections across all fleets in that stock_ticker (not filtering on anything) / sum of all tractors from all fleets in that stock_ticker(regardless if they had an inspection or not, but requiring to own tractors and >1 mlg150

-- inspections per 1000 tractors per stock_tickers -- joins
    INSERT INTO staging.dbo.indx_index_data (data_timestamp, data_value, index_id, granularity_item_id)
	SELECT aa.summary_date AS data_timestamp, 
		   (CAST(aa.inspections AS FLOAT) / CAST(bb.tractors AS FLOAT)) * 1000 AS data_value, --divide the inspections/number of tractors
		   index_id = '1047', 
		   c.id AS granularity_item_id
	FROM (		SELECT	a.summary_date, 
						b.stock_ticker, 
						SUM(a.insps) AS inspections
				FROM 	(	SELECT	DOT_NUMBER, 
									summary_date, 
									COUNT(DISTINCT(inspection_id)) as INSPS
							FROM #all
							GROUP BY DOT_NUMBER, summary_date) a --all the inspections by DOT number
		 INNER JOIN
		(
				SELECT DISTINCT 
						DOT_number, 
						stock_ticker
				FROM Warehouse.dbo.FMCSA_census_parent_child
		) b --which DOT_numbers belong to which parent group (stock ticker)
		 ON a.DOT_number = b.DOT_number
		GROUP BY a.summary_date, 
				 b.Stock_Ticker) aa
		 INNER JOIN #tract bb ON aa.stock_ticker = bb.stock_ticker
								AND aa.summary_date = bb.asofdate
		 INNER JOIN
	(
		SELECT *
		FROM staging.dbo.indx_granularity_item
		WHERE granularity_level_id = 19
	) c ON aa.stock_ticker = c.granularity1
		ORDER BY granularity_item_id,data_timestamp
		
		--select top(10)*
		--from staging.dbo.indx_index_data
		--where index_id=1047 and granularity_item_id in (3831,8727) and data_timestamp >= '2019-08-09'
		--order by granularity_item_id, data_timestamp asc
		

---------------
--- > VIOT <---
---------------

--1048	Violations per 1000 Tractors					VIOT	M	RATIO	Monthly Ratio of Violations to 1000 Tractors

		
-- summing violations by DOT_number and then by stock ticker (parent group) 
-- fill in missing that have no counts - there are no missing counts here

    INSERT INTO staging.dbo.indx_index_data (data_timestamp, data_value, index_id, granularity_item_id)
	SELECT a.summary_date, 
		   (CAST(ISNULL(b.violations, 0) AS FLOAT) / CAST(c.tractors AS FLOAT)) * 1000 AS data_value, 
		   index_id = '1048',
		   a.granularity_item_id
	FROM #combos a -- all combinations - left join to get all
		 LEFT JOIN
	(
		SELECT aa.summary_date, 
			   bb.stock_ticker, 
			   SUM(aa.viol) AS violations --summing violations per parent group (aka stock ticker/granularity)
		FROM
		(
			SELECT DOT_NUMBER, 
				   summary_date, 
				   SUM(violations) AS viol
			FROM #all
			GROUP BY dot_number, 
					 summary_date
		) aa --all the violations by DOT number
		INNER JOIN
		(
			SELECT DISTINCT 
				   DOT_number, 
				   stock_ticker
			FROM Warehouse.dbo.FMCSA_census_parent_child
		) bb --which DOT_numbers belong to which parent group (stock ticker)
		ON aa.DOT_number = bb.DOT_number
		GROUP BY aa.summary_date, 
				 bb.Stock_Ticker
	) b ON a.summary_date = b.summary_date
		   AND a.Stock_Ticker = b.Stock_Ticker
		 INNER JOIN #tract c --denominator (number of tractors per stock_ticker and date)
						ON a.stock_ticker = c.stock_ticker
						AND a.summary_date = c.asofdate
	ORDER BY a.granularity_item_id, a.summary_date;

		/*select top(10)*
		from staging.dbo.indx_index_data
		where index_id=1048 and granularity_item_id in (3831,8727) and data_timestamp >= '2019-05-09'
		order by granularity_item_id, data_timestamp asc
		*/

--------------
---> OOST <---
--------------

--1049	Out of Service Violations per 1000 Tractors			OOST	M	RATIO	Monthly Ratio of Out of Service Violations to 1000 Tractors

-- OOS violations per 1000 tractors per stock_tickers 

    INSERT INTO staging.dbo.indx_index_data (data_timestamp, data_value, index_id, granularity_item_id)
	SELECT c.summary_date AS data_timestamp, 
		   (CAST(c.oos AS FLOAT) / CAST(d.tractors AS FLOAT)) * 1000 AS data_value, 
		   index_id = '1049', 
		   c.granularity_item_id
	FROM
	(
		SELECT a.summary_date, 
			   a.stock_ticker, 
			   a.granularity_item_id, 
			   ISNULL(b.oos, 0) AS oos
		FROM #combos a
			 LEFT JOIN
		(
			SELECT aa.summary_date, 
				   bb.stock_ticker, 
				   SUM(aa.viol) AS oos
			FROM
			(
				SELECT DOT_NUMBER, 
					   summary_date, 
					   SUM(OOS_total) AS viol
				FROM #all
				GROUP BY DOT_NUMBER, 
						 summary_date
			) aa --all the oos violations by DOT number
			INNER JOIN
			(
				SELECT DISTINCT 
					   DOT_number, 
					   stock_ticker
				FROM Warehouse.dbo.FMCSA_census_parent_child
			) bb --which DOT_numbers belong to which parent group (stock ticker)
			ON aa.DOT_number = bb.DOT_number
			GROUP BY aa.summary_date, 
					 bb.Stock_Ticker
		) b ON a.summary_date = b.summary_date
			   AND a.Stock_Ticker = b.Stock_Ticker
	) c
	INNER JOIN #tract d ON c.stock_ticker = d.stock_ticker
						   AND c.summary_date = d.asofdate
	ORDER BY data_timestamp, 
			 granularity_item_id;
/*
		select top(10)*
		from staging.dbo.indx_index_data
		where index_id=1049 and granularity_item_id in (3831,8727) and data_timestamp >= '2019-05-09'
		order by granularity_item_id, data_timestamp asc
*/
-------------
--> ACDTT <--
-------------
--1050	DOT Reportable Accidents per 1000 Tractors			ACDTT	M	RATIO	Monthly Ratio of DOT Reportable Accidents to 1000 Tractors


-- accidents per 1000 tractors per stock_tickers 

    INSERT INTO staging.dbo.indx_index_data (data_timestamp, data_value, index_id, granularity_item_id)
	SELECT aa.summary_date AS data_timestamp, 
		   (CAST(aa.acc AS FLOAT) / CAST(bb.tractors AS FLOAT)) * 1000 AS data_value, 
		   index_id = '1050', 
		   aa.granularity_item_id
	FROM
	(
		SELECT c.summary_date, 
			   c.stock_ticker, 
			   c.granularity_item_id, 
			   ISNULL(d.acc, 0) AS acc
		FROM #combos c
			 LEFT JOIN
		(
			SELECT a.summary_date, 
				   b.stock_ticker, 
				   SUM(a.accidents) AS acc
			FROM
			(
				SELECT DOT_NUMBER, 
					   summary_date, 
					   COUNT(crash_id) AS accidents
				FROM #allc
				GROUP BY DOT_NUMBER, 
						 summary_date
			) a --all the accidents by DOT number
			INNER JOIN
			(
				SELECT DISTINCT 
					   DOT_number, 
					   stock_ticker
				FROM Warehouse.dbo.FMCSA_census_parent_child
			) b --which DOT_numbers belong to which parent group (stock ticker)
			ON a.DOT_number = b.DOT_number
			GROUP BY a.summary_date, 
					 b.Stock_Ticker
		) d ON c.summary_date = d.summary_date
			   AND c.Stock_Ticker = d.Stock_Ticker
	) aa
	INNER JOIN #tract bb ON aa.stock_ticker = bb.stock_ticker
							AND aa.summary_date = bb.asofdate
	ORDER BY data_timestamp, 
			 granularity_item_id;


-------------
--> FATLT <--
-------------
--1051	Fatalities from DOT Reportable Accidents per 1000 Tractors	FATLT	M	RATIO	Monthly Ratio of Fatalities from DOT Reportable Accidents to 1000 Tractors 

-- fatalities per 1000 tractors per stock_tickers 

    INSERT INTO staging.dbo.indx_index_data (data_timestamp, data_value, index_id, granularity_item_id)
	SELECT aa.summary_date AS data_timestamp, 
		   (CAST(aa.fat AS FLOAT) / CAST(bb.tractors AS FLOAT)) * 1000 AS data_value, 
		   index_id = '1051', 
		   aa.granularity_item_id
	FROM
	(
		SELECT c.summary_date, 
			   c.stock_ticker, 
			   c.granularity_item_id, 
			   ISNULL(d.fat, 0) AS fat
		FROM #combos c
			 LEFT JOIN
		(
			SELECT a.summary_date, 
				   b.stock_ticker, 
				   SUM(a.fatalities) AS fat
			FROM
			(
				SELECT DOT_NUMBER, 
					   summary_date, 
					   SUM(FATALITIES) AS fatalities
				FROM #allc
				GROUP BY DOT_NUMBER, 
						 summary_date
			) a --all the fatalities by DOT number
			INNER JOIN
			(
				SELECT DISTINCT 
					   DOT_number, 
					   stock_ticker
				FROM Warehouse.dbo.FMCSA_census_parent_child
			) b --which DOT_numbers belong to which parent group (stock ticker)
			ON a.DOT_number = b.DOT_number
			GROUP BY a.summary_date, 
					 b.Stock_Ticker
		) d ON c.summary_date = d.summary_date
			   AND c.Stock_Ticker = d.Stock_Ticker
	) aa
	INNER JOIN #tract bb ON aa.stock_ticker = bb.stock_ticker
							AND aa.summary_date = bb.asofdate
	ORDER BY data_timestamp, 
			 granularity_item_id;

------------
--> INJT <--
------------
--1052	Injuries from DOT Reportable Accidents per 1000 Tractors	INJT	M	RATIO	Monthly Ratio of Injuries from DOT Reportable Accidents to 1000 Tractors
-- updated numbers - injuries per 1000 tractors per stock_tickers 

    INSERT INTO staging.dbo.indx_index_data (data_timestamp, data_value, index_id, granularity_item_id)
	SELECT aa.summary_date AS data_timestamp, 
		   (CAST(aa.inj AS FLOAT) / CAST(bb.tractors AS FLOAT)) * 1000 AS data_value, 
		   index_id = '1052', 
		   aa.granularity_item_id
	FROM (
		SELECT c.summary_date, 
		   c.stock_ticker, 
		   c.granularity_item_id,
		   ISNULL(d.inj, 0) AS inj   
	FROM #combos c
		 LEFT JOIN (
	SELECT a.summary_date, 
		   b.stock_ticker, 
		   SUM(a.injuries) AS inj
	FROM (	SELECT DOT_NUMBER, summary_date, SUM(INJURIES) AS injuries
			from #allc
			GROUP BY DOT_NUMBER, summary_date
	)
	 a --all the injuries by DOT number
		 INNER JOIN
	(
		SELECT DISTINCT 
			   DOT_number, 
			   stock_ticker
		FROM Warehouse.dbo.FMCSA_census_parent_child
	) b --which DOT_numbers belong to which parent group (stock ticker)
		 ON a.DOT_number = b.DOT_number
	GROUP BY a.summary_date, 
			 b.Stock_Ticker
		 ) d ON c.summary_date = d.summary_date
								  AND c.Stock_Ticker = d.Stock_Ticker
	
	) aa
		 INNER JOIN #tract bb ON aa.stock_ticker = bb.stock_ticker
								AND aa.summary_date = bb.asofdate
	ORDER BY data_timestamp, granularity_item_id;


-- CTE statement to keep only the most recent (deletes from staging the 6 months of data to be replaced)
/*	DECLARE @datetouse DATE = '' -- EC: Set datetouse as a parameter, that way an alternate date can be used without altering code. Also shouldnt this be a date not datetime
	SET @datetouse = (SELECT CASE
								WHEN @datetouse = '1900-01-01' THEN dateadd(month, -4,max(data_timestamp)) 
								ELSE @datetouse
							 END as date_to_use
					  FROM Staging.dbo.indx_index_data
					  WHERE index_id BETWEEN 1047 AND 1052) -- EC: If no date is provided, query indx_index_data to get the max timestamp minus 5 months, else use provided date

		SELECT index_id,
			   data_timestamp,
			   granularity_item_id,
			   data_value,
			   ROW_NUMBER() OVER (PARTITION BY index_id, granularity_item_id, data_timestamp ORDER BY createdate DESC) as RN
		FROM Staging.dbo.indx_index_data
		WHERE index_id IN (1047,1048,1049,1050,1051,1052) and data_timestamp >= @datetouse --can I put @EndDate in here? --EC: Yep!
		*/

	WITH dedup as (
		SELECT index_id,
			   data_timestamp,
			   granularity_item_id,
			   data_value,
			   ROW_NUMBER() OVER (PARTITION BY index_id, granularity_item_id, data_timestamp ORDER BY createdate DESC) as RN
		FROM Staging.dbo.indx_index_data
		WHERE index_id IN (1047,1048,1049,1050,1051,1052) and data_timestamp >= @datetouse --can I put @EndDate in here? --EC: Yep!
	)
	DELETE
	FROM dedup
	WHERE RN > 1
 
-- Drop all the temp tables

	DROP TABLE IF EXISTS #all;
	DROP TABLE IF EXISTS #allc;
	DROP TABLE IF EXISTS #t1;
	DROP TABLE IF EXISTS #tract;
	DROP TABLE IF EXISTS #combos;



END


		--SELECT index_id,
		--	   data_timestamp,
		--	   granularity_item_id,
		--	   data_value,
		--	   ROW_NUMBER() OVER (PARTITION BY index_id, granularity_item_id, data_timestamp ORDER BY createdate DESC) as RN
		--FROM Staging.dbo.indx_index_data
		--WHERE index_id IN (1047,1048,1049,1050,1051,1052) and data_timestamp >= '2019-06-30'-- and granularity_item_id=1
		--order by index_id, granularity_item_id, data_timestamp


		--select *
		--FROM Staging.dbo.indx_index_data
		--WHERE index_id IN (1047,1048,1049,1050,1051,1052) and data_timestamp = '2020-01-09'

		--select top(100)*
		--from staging.dbo.indx_index_definition 
		--WHERE id IN (1047,1048,1049,1050,1051,1052)


		--SELECT index_id, granularity_item_id,
		--max(createdate)
		--FROM Staging.dbo.indx_index_data
		--WHERE index_id IN (1047,1048,1049,1050,1051,1052)
		--group by index_id,granularity_item_id

