USE [Staging]
GO
/****** Object:  StoredProcedure [dbo].[create_APS_APHS_FATL_INJ]    Script Date: 9/25/2019 2:05:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kate Fisher
-- Create date: 2019-09-20
-- Description:	Create tickers APS, APHS, FATL, INJ
-- New assumptions:
--		Only count each crash_id once, using latest 'change date'.
--		If there are no counts, set to 0 instead of missing
--		All states + DC counts towards USA count
--		Revise 6 months of history
-- =============================================
ALTER PROCEDURE [dbo].[create_APS_APHS_FATL_INJ] 


	@EndDate date = '', -- EC: Making this variable a parameter allows you to run the proc with a different end date, if needed, without changing code
	@MaxDate date = '' -- EC: Making this variable a parameter allows you to run the proc with a different end date, if needed, without changing code


AS
BEGIN

--id	index_name	ticker
--186	DoT Reportable Accidents per State - Monthly	APS							--national and state
--187	DoT Reportable Accidents per Ten Thousand Highway Miles by State	APHS	--just state
--194	Commercial Vehicle Accident Fatalities	FATL								--national and state
--195	Commercial Vehicle Accident Injuries	INJ									--national and state

	--declare @EndDate date --for testing
	--set @EndDate = '1900-01-01' --for testing
	SET @EndDate = (CASE WHEN @EndDate = '1900-01-01' THEN EOMonth(dateadd(mm, -6, getdate())) ELSE @EndDate END) -- EC: If the parameter is not provided, use the default of 6 months prior to todays date
	--select @EndDate--for testing
	
	--declare @MaxDate date --for testing
	--set @MaxDate = '1900-01-01' --for testing
	SET @MaxDate= (SELECT CASE
								WHEN @MaxDate = '1900-01-01' THEN EOMONTH(DATEADD(month,-1,MAX(CONVERT(DATE, CAST(REPORT_DATE AS VARCHAR))))) --only allow up to 2 months prior
								ELSE @MaxDate
							 END as max_date
					FROM warehouse.dbo.FMCSA_Crash_Master_LOAD) 
	--select @MaxDate --for testing


---> Main CRASH dataset <---
-- get records/variables of interest from warehouse.dbo.FMCSA_Crash_Master

	DROP TABLE IF EXISTS #allc;
	SELECT 
		--	row_number() as id,
		   ROW_NUMBER() OVER (ORDER BY REPORT_DATE) as row_num,
		   a.CRASH_ID, 
		   a.dot_number, 
		   a.report_state, 
		   a.REPORT_NUMBER, 
		   cast(REPORT_DATE as date) as REPORT_DATE, -- report date
		   EOMonth(cast(REPORT_DATE as date)) as data_timestamp , 
		   cast(FATALITIES as int) as FATALITIES, -- for fatalities
		   cast(INJURIES as int) as INJURIES, -- for injuries
		   cast(ADD_DATE as date) as ADD_DATE, -- add date
		   cast(UPLOAD_DATE as date) as UPLOAD_DATE, -- upload date
		   cast(CHANGE_DATE as date) as CHANGE_DATE -- change date - use for duplicates- take latest
	INTO #allc
	FROM warehouse.dbo.FMCSA_Crash_Master_LOAD a -- temporarily using LOAD
	WHERE report_state IN('AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY')-- must happen in US
	and  EOMONTH(CONVERT(DATE, CAST(REPORT_DATE AS VARCHAR))) >= @EndDate    --replace 6 months of data
	--and  EOMONTH(CONVERT(DATE, CAST(REPORT_DATE AS VARCHAR))) <  EOMONTH(GETDATE()); --get the month before as latest since data isn't all in yet for the month
	and  EOMONTH(CONVERT(DATE, CAST(REPORT_DATE AS VARCHAR))) <  @MaxDate ; --get the month before as latest since data isn't all in yet for the month

	-- cte to remove duplicate crash_id
	WITH dedup as (
		SELECT *,
			   ROW_NUMBER() OVER (PARTITION BY crash_id ORDER BY change_date DESC) as RN
		FROM #allc
	)
	DELETE
	FROM dedup
	WHERE RN > 1


	--select top (100)*
	--from #allc

--186	DoT Reportable Accidents per State - Monthly	APS

	DROP TABLE IF EXISTS #acc_state1;--needed for later
	SELECT data_timestamp, 
		   report_state, 
		   COUNT(crash_id) AS data_value, 
		   index_id = 186
	INTO #acc_state1
	FROM #allc
	WHERE report_state != 'DC'
	GROUP BY data_timestamp, 
			 report_state
	ORDER BY data_timestamp, 
			 report_state;

  -- by USA
  	INSERT INTO staging.dbo.indx_index_data (data_timestamp, granularity_item_id, data_value, index_id)
	SELECT data_timestamp, 
		   1 as granularity_item_id, 
		   COUNT(crash_id) AS data_value, 
		   index_id = 186
	FROM #allc
	GROUP BY data_timestamp
	ORDER BY data_timestamp;


-- get all dates and places
-- make sure all dates are represented. fill in zeros

	DROP TABLE IF EXISTS #alldates;
	SELECT a.data_timestamp, 
		   b.report_state,
		   b.granularity_item_id
	INTO #alldates
	FROM
	(
		SELECT DISTINCT
			   (data_timestamp) AS data_timestamp
		FROM #acc_state1
	) a
	CROSS JOIN
	(   SELECT aa.report_state, bb.id as granularity_item_id
		FROM (SELECT DISTINCT
			   (report_state) AS report_state
		FROM #acc_state1 
		WHERE report_state !='DC') aa
		INNER JOIN (SELECT id, granularity1 from staging.dbo.indx_granularity_item where granularity_level_id=4) bb
		on aa.report_state=bb.granularity1
	) b;

-- by state
  	INSERT INTO staging.dbo.indx_index_data (data_timestamp, granularity_item_id, data_value, index_id)
	SELECT b.data_timestamp, 
		   b.granularity_item_id,
		   ISNULL( a.data_value, 0 ) AS data_value, 
		   186 AS index_id
	FROM #alldates  b --all combinations
	LEFT JOIN
	#acc_state1 a
	ON a.data_timestamp=b.data_timestamp
	   AND a.report_state=b.report_state;

	   /*
	   select top(100)*
	   from staging.dbo.indx_index_data
	   where index_id=186 and granularity_item_id in (350,349) and data_timestamp >='2019-05-31'
	   order by granularity_item_id,data_timestamp
	   */

--187	DoT Reportable Accidents per Ten Thousand Highway Miles by State	APHS

	INSERT INTO staging.dbo.indx_index_data (data_timestamp, data_value, granularity_item_id, index_id)
	SELECT  aa.data_timestamp,
			ISNULL(bb.data_value, 0 ) AS data_value, 
			aa.granularity_item_id ,
			index_id = 187 
	FROM #alldates aa --all combinations, making sure that all dates are filled in 
	LEFT JOIN
	(SELECT a.data_timestamp, 
		    a.report_state, 
		    CAST(a.data_value AS DEC(15, 5)) / c.Lane_Miles * 10000 AS data_value
	FROM #acc_state1 a --all the accidents, joined by mileage by state
		 INNER JOIN Warehouse.dbo.Interstate_Miles_by_State c ON a.REPORT_STATE = c.[state] ) bb 
		 on aa.data_timestamp=bb.data_timestamp and aa.report_state=bb.report_state
	ORDER BY aa.report_state, 
			 aa.data_timestamp;

	   /*
	   select top(100)*
	   from staging.dbo.indx_index_data
	   where index_id=187 and granularity_item_id in (350,349) and data_timestamp >='2019-05-31'
	   order by granularity_item_id,data_timestamp
	   */

--187	DoT Reportable Accidents per Ten Thousand Highway Miles by USA	APHS 
	INSERT INTO staging.dbo.indx_index_data (data_timestamp, data_value, granularity_item_id, index_id)
	SELECT	a.data_timestamp,  
			CAST(a.nat_data_value AS DEC(15, 5)) / c.national_lane_miles * 10000 AS data_value,
			granularity_item_id=1,
			index_id = 187
	FROM
	(
		SELECT data_timestamp, 
			   SUM(data_value) AS nat_data_value
		FROM #acc_state1
		GROUP BY data_timestamp
	) a --all the accidents
	CROSS JOIN
	(
		SELECT SUM(lane_miles) AS national_lane_miles
		FROM Warehouse.dbo.Interstate_Miles_by_State
	) c

	/*
	   select top(100)*
	   from staging.dbo.indx_index_data
	   where index_id=187 and granularity_item_id =1 and data_timestamp >='2019-05-31'
	   order by granularity_item_id,data_timestamp
	*/



--194	Commercial Vehicle Accident Fatalities	FATL
  -- by state,  making sure that all dates are filled in 

    INSERT INTO staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT ISNULL( a.data_value, 0 )AS data_value, 
		   b.data_timestamp, 
		   b.granularity_item_id, 
		   194 AS index_id -- fatalities

	FROM #alldates b --all combinations
	LEFT JOIN
	(SELECT		data_timestamp, 
				report_state, 
				SUM(FATALITIES) AS data_value 
		FROM #allc
		WHERE report_state != 'DC' 
		GROUP BY data_timestamp, 
				 report_state) a
	ON a.data_timestamp=b.data_timestamp
	   AND a.report_state=b.report_state;


 -- USA
    INSERT INTO staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT SUM(FATALITIES) AS data_value, 
		   data_timestamp, 
		   1 AS granularity_item_id, 
		   index_id = 194
	FROM #allc
	GROUP BY data_timestamp
	ORDER BY data_timestamp;


--195	Commercial Vehicle Accident Injuries	INJ

-- by state
    INSERT INTO staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT ISNULL( a.data_value, 0 )AS data_value, 
		   b.data_timestamp, 
		   b.granularity_item_id, 
		   195 as index_id
	FROM #alldates b --all combinations
	LEFT JOIN
	(SELECT data_timestamp, 
		   report_state, 
		   SUM(INJURIES) AS data_value
		FROM #allc
		WHERE report_state != 'DC'
		GROUP BY data_timestamp, 
				 report_state) a
	ON a.data_timestamp=b.data_timestamp
	   AND a.report_state=b.report_state;


-- USA
    INSERT INTO staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT SUM(INJURIES) AS data_value,
		   data_timestamp, 
		   1 AS granularity_item_id, 
		   195 as index_id
	FROM #allc
	GROUP BY data_timestamp
	ORDER BY data_timestamp;

-- drop the temp tables
	DROP TABLE IF EXISTS #allc;
	DROP TABLE IF EXISTS #acc_state1;
	DROP TABLE IF EXISTS #alldates;

-- CTE statement to keep only the most recent (deletes from staging the 6 months of data to be replaced)

--186	DoT Reportable Accidents per State - Monthly	APS							--national and state
--187	DoT Reportable Accidents per Ten Thousand Highway Miles by State	APHS	--just state
--194	Commercial Vehicle Accident Fatalities	FATL								--national and state
--195	Commercial Vehicle Accident Injuries	INJ									--national and state

--testing
/*
	declare @EndDate date --for testing
	set @EndDate = '1900-01-01' --for testing
	SET @EndDate = (CASE WHEN @EndDate = '1900-01-01' THEN EOMonth(dateadd(mm, -6, getdate())) ELSE @EndDate END) 
	select @EndDate
		SELECT index_id,
			   data_timestamp,
			   granularity_item_id,
			   data_value,
			   ROW_NUMBER() OVER (PARTITION BY index_id, granularity_item_id, data_timestamp ORDER BY createdate DESC) as RN
		FROM Staging.dbo.indx_index_data
		WHERE index_id IN (195, 194, 186, 187) and data_timestamp >= @EndDate
*/

	;WITH dedup as (
		--declare @EndDate date = EOMonth(dateadd(mm, -6, getdate()))
		SELECT index_id,
			   data_timestamp,
			   granularity_item_id,
			   data_value,
			   ROW_NUMBER() OVER (PARTITION BY index_id, granularity_item_id, data_timestamp ORDER BY createdate DESC) as RN
		FROM Staging.dbo.indx_index_data
		WHERE index_id IN (195, 194, 186, 187) and data_timestamp >= @EndDate 
	)
	DELETE
	FROM dedup
	WHERE RN > 1




END

		--select a.data_timestamp, a.data_value, a.index_id, b.*, c.*
		--from
		--(SELECT *
		--FROM Staging.dbo.indx_index_data
		--WHERE index_id IN (195, 194, 186, 187) and data_timestamp >= '2019-05-31') a
		--left join staging.dbo.indx_granularity_item b
		--on a.granularity_item_id=b.id
		--left join (	select description, id, index_name, ticker
		--			from staging.dbo.indx_index_definition ) c
		--			on a.index_id=c.id
		--order by index_id, granularity_item_id, data_timestamp

		--SELECT index_id,
		--	   data_timestamp,
		--	   granularity_item_id,
		--	   data_value,
		--	   ROW_NUMBER() OVER (PARTITION BY index_id, granularity_item_id, data_timestamp ORDER BY createdate DESC) as RN
		--FROM Staging.dbo.indx_index_data
		--WHERE index_id IN (195, 194, 186, 187) and granularity_item_id=1 and data_timestamp >= '2019-05-31'







