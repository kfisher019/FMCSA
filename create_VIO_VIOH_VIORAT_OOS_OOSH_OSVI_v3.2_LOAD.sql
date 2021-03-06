USE [Staging]
GO
/****** Object:  StoredProcedure [dbo].[create_VIO_VIOH_VIORAT_OOS_OOSH_OSVI]    Script Date: 9/25/2019 2:49:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- EXEC [dbo].[create_VIO]
--Author: Kate Fisher
--Date: Sep 16, 2019
--Purpose: create 6 tickers related to counting violations and out of service violations per month overall and by state
--New assumptions: Only count tractor trailer inspections (INSP_UNIT_TYPE_ID =11), use the inspection_id

ALTER procedure [dbo].[create_VIO_VIOH_VIORAT_OOS_OOSH_OSVI]

	@EndDate date = '' -- EC: setting EndDate as a parameter allows us to run the proc with the default end date or with a custom end date without changing code

as

begin

	--Declare @EndDate DATE = '' --for testing
	SET @EndDate = (CASE WHEN @EndDate = '1900-01-01' THEN EOMonth(dateadd(mm, -6, getdate())) ELSE @EndDate END) -- EC: If no date value is provided use the default date of 6 months priori from todays date
	--select @EndDate

	--declare @MaxDate DATE = '' --uncomment for testing
	SET @MaxDate= (SELECT CASE
								WHEN @MaxDate = '1900-01-01' THEN DATEADD(DAY, 8, DATEADD(MONTH, DATEDIFF(MONTH, 0,MAX(CONVERT(DATE, CAST(INSP_DATE AS VARCHAR)))), 0))
								ELSE @MaxDate
							 END as max_date
					FROM warehouse.dbo.FMCSA_Insp_Load) 
	--select @MaxDate


--------------------
--> Main dataset <--
--------------------

-- using this method where counting all violations where there was evidence of a TT being involved in the inspection_id (and not requiring the actual violation to be tagged with a TT, because maybe it was a driver violation)

-- merge inspection, with violation, with type of violation
	DROP TABLE IF EXISTS #TempI;
	SELECT a.OOS_TOTAL, 
		   a.VIOL_TOTAL, 
		   a.INSPECTION_ID, 
		   a.REPORT_STATE, 
		   a.CHANGE_DATE, --adding to remove duplicate inspection_ids
		   EOMONTH(CONVERT(DATE, CAST(a.INSP_DATE AS VARCHAR))) AS data_timestamp, -- using end of month! 
		   f.INSP_UNIT_TYPE_ID,
		   e.id as granularity_item_id
	INTO #TempI
	FROM (	select OOS_TOTAL, VIOL_TOTAL, INSPECTION_ID, INSP_DATE, REPORT_STATE, CHANGE_DATE --adding CHANGE_DATE since there maybe duplicate records for inspection_ids
			from Warehouse.dbo.FMCSA_Insp_LOAD -- TEMPORARILY USING LOAD
			where EOMONTH(CONVERT(DATE, CAST(INSP_DATE AS VARCHAR))) >= @EndDate  and EOMONTH(CONVERT(DATE, CAST(INSP_DATE AS VARCHAR))) < @MaxDate --EOMONTH(GETDATE())
			and REPORT_STATE IN('AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY')) a -- this is the inspection- gives state and date
		 INNER JOIN
	(
		SELECT DISTINCT 
			   INSPECTION_ID, 
			   INSP_UNIT_TYPE_ID
		FROM Warehouse.dbo.FMCSA_Insp_Unit_LOAD -- TEMPORARILY USING LOAD
		WHERE INSP_UNIT_TYPE_ID = 11
	) f --to get type of unit the violation was on
		 ON a.INSPECTION_ID = f.INSPECTION_ID
		 LEFT JOIN
	(
		SELECT id, 
			   granularity1
		FROM Staging.dbo.indx_granularity_item
		WHERE granularity_level_id = 4
	) e ON a.REPORT_STATE = e.granularity1

--	-- check inspections only represented once. Critical for rest of code!
--select count(*)
--from #TempI

--select count(distinct(inspection_id))
--from #TempI


	;WITH dedup as (
		--declare @EndDate date = EOMonth(dateadd(mm, -6, getdate())) -- uncomment to check it
		SELECT *,
			   ROW_NUMBER() OVER (PARTITION BY INSPECTION_ID ORDER BY CHANGE_DATE DESC) as RN
		FROM #tempI
	)

	DELETE
	FROM dedup
	WHERE RN > 1


---> start of by month code <---

---> 1. VIO <---
--197	Total Violations Reported to FMCSA	VIO	M	VIOLATIONS	Sum of Violations (Truck and Driver) Reported to FMCSA. Subject to revision.

-- USA
	DROP TABLE IF EXISTS #usa1; --need this later for denominator
	SELECT SUM(cast(viol_total as numeric)) AS data_value, 
		   data_timestamp, 
		   1 AS granularity_item_id,
		   197 as index_id
	INTO #usa1
	FROM #tempI
	GROUP BY data_timestamp
	ORDER BY data_timestamp

	INSERT INTO Staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT data_value, 
		   data_timestamp, 
		   granularity_item_id, 
		   index_id
	FROM #usa1
	ORDER BY granularity_item_id, data_timestamp

	
	select top(10) *
	from staging.dbo.indx_index_data
	where index_id=197 and data_timestamp >'2019-04-30' and granularity_item_id=1
	order by data_timestamp


-- STATE
	DROP TABLE IF EXISTS #state1; --used later to get all combinations dataset
	SELECT SUM(cast(viol_total as numeric)) AS data_value, 
		   data_timestamp, 
		   granularity_item_id,
		   197 as index_id
	INTO #state1
	FROM #tempI
	WHERE REPORT_STATE != 'DC' 
	GROUP BY data_timestamp,granularity_item_id
	ORDER BY data_timestamp,granularity_item_id;


-- make sure all dates are represented. fill in zeros
	DROP TABLE IF EXISTS #alldates;
	SELECT a.data_timestamp, 
		   b.granularity_item_id
	INTO #alldates
	FROM
	(
		SELECT DISTINCT
			   (data_timestamp) AS data_timestamp
		FROM #state1
	) a
	CROSS JOIN
	(
		SELECT DISTINCT
			   (granularity_item_id) AS granularity_item_id
		FROM #state1
	) b;

	-- by states
	DROP TABLE IF EXISTS #state2; -- need it for later tables (denominator)
	SELECT ISNULL( a.data_value, 0 ) AS data_value, 
		   b.data_timestamp, 
		   b.granularity_item_id, 
		   197 AS index_id
	INTO #state2
	FROM #alldates b --all combinations
	LEFT JOIN  -- EC: Why a left join instead of an inner?
	#state1 a
	ON a.data_timestamp=b.data_timestamp
	   AND a.granularity_item_id=b.granularity_item_id;

	INSERT INTO Staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT data_value, 
		   data_timestamp, 
		   granularity_item_id, 
		   index_id
	FROM #state2
	ORDER BY granularity_item_id, data_timestamp

	
	--select top(10) *
	--from staging.dbo.indx_index_data
	--where index_id=197 and data_timestamp >'2019-04-30' and granularity_item_id in (349, 350)
	--order by granularity_item_id, data_timestamp
	

---> 2. violations per interstate miles per state <---
-- 203	Total Violations per State Highway Mile in 1000s	VIOH	M	INDX	Sum of Violations per 1000 state highway miles
-- just state

-- VIOH
	INSERT INTO staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT a.data_value / (c.Lane_Miles / 1000) AS data_value, -- number of violations per 1000 miles 
		   a.data_timestamp, 
		   a.granularity_item_id, 
		   203 AS index_id
	FROM #state2 a --already has 0s filled in
		 INNER JOIN
	(
		SELECT granularity1, 
			   id
		FROM staging.dbo.indx_granularity_item
		WHERE granularity_level_id = 4
	) b ON a.granularity_item_id = b.id
		 INNER JOIN Warehouse.dbo.Interstate_Miles_by_State c ON b.granularity1 = c.[state]
	ORDER BY granularity_item_id, 
			 data_timestamp;

	
	--select top(10) *
	--from staging.dbo.indx_index_data
	--where index_id=203 and data_timestamp >'2019-04-30' and granularity_item_id in (349, 350)
	--order by granularity_item_id, data_timestamp
	

---> 3. number of violations per inspection <---
-- 598	Violations to Inspections Ratio	VIORAT	M	RATIO	Number of Violations for every One Inspection
-- USA and state

-- VIORAT- USA
	INSERT INTO staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT 
		a.data_value / b.ninsp AS data_value, -- number of violations per inspection 
		a.data_timestamp, 
		1 AS granularity_item_id, 
		598 AS index_id
	FROM #USA1 a
		 INNER JOIN 	(SELECT data_timestamp, COUNT(inspection_id) AS ninsp 
						FROM #tempI
						GROUP BY data_timestamp) b  --number of inspections - denominator
		ON a.data_timestamp = b.data_timestamp
	order by data_timestamp

	
	--select top(10) *
	--from staging.dbo.indx_index_data
	--where index_id=598 and data_timestamp >'2019-04-30' and granularity_item_id=1
	--order by granularity_item_id, data_timestamp
	

-- VIORAT - by State
	INSERT INTO staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT a.data_value / b.ninsp AS data_value, -- number of violations per inspection 
		   a.data_timestamp, 
		   a.granularity_item_id, 
		   598 AS index_id
	FROM #STATE2 a
		 INNER JOIN
	(
		SELECT ISNULL(bb.ninsp, 1) AS ninsp, --divide by 1 instead of by 0 (ninsp is the denominator for VIORAT)
			   aa.data_timestamp, 
			   aa.granularity_item_id
		FROM #alldates aa --all dates/granularity combos
			 LEFT JOIN
		(
			SELECT granularity_item_id, 
				   data_timestamp, 
				   COUNT(inspection_id) AS ninsp --distinct is overkill (unless we just append the FMCSA files...which we shouldn't, let's truncate and replace all of 2019)
			FROM #tempI --count all inspection_ids
			GROUP BY granularity_item_id, 
					 data_timestamp
		) bb ON aa.data_timestamp = bb.data_timestamp
				AND aa.granularity_item_id = bb.granularity_item_id
	) b --number of inspections - denominator
	ON a.data_timestamp = b.data_timestamp
		   AND a.granularity_item_id = b.granularity_item_id
	ORDER BY granularity_item_id, data_timestamp



---> 4. OOS <---
-- 198	Total Violations Resulting in Out of Service	OOS	M	VIOLATIONS	Sum of Violations (Truck and Driver) which resulted in going out of service

-- USA
	DROP TABLE IF EXISTS #ousa1; --needed for later calculations
	SELECT SUM(cast(OOS_TOTAL as numeric)) AS data_value, 
		   data_timestamp, 
		   1 AS granularity_item_id,
		   198 as index_id
	INTO #ousa1
	FROM #tempI
	GROUP BY data_timestamp
	ORDER BY data_timestamp

	INSERT INTO Staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT data_value, 
		   data_timestamp, 
		   granularity_item_id, 
		   index_id
	FROM #ousa1
	ORDER BY granularity_item_id, data_timestamp

	
	--select top(10) *
	--from staging.dbo.indx_index_data
	--where index_id=198 and data_timestamp >='2019-04-30' and granularity_item_id=1
	--order by granularity_item_id, data_timestamp
	


-- STATE

-- make sure all dates are represented. fill in zeros
	DROP TABLE IF EXISTS #ostate2; --needed for later calculations
	SELECT ISNULL( a.data_value, 0 )
	AS data_value, 
		   b.data_timestamp, 
		   b.granularity_item_id, 
		   198 AS index_id
	INTO #ostate2
	FROM #alldates
	AS b --all combinations
	LEFT JOIN
	(SELECT SUM(cast(oos_total as numeric)) AS data_value, 
		   data_timestamp, 
		   granularity_item_id
	FROM #tempI
	GROUP BY data_timestamp,granularity_item_id)
	AS a
	ON a.data_timestamp=b.data_timestamp
	   AND a.granularity_item_id=b.granularity_item_id;

	INSERT INTO Staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT data_value, 
		   data_timestamp, 
		   granularity_item_id, 
		   index_id
	FROM #ostate2
	ORDER BY granularity_item_id, data_timestamp

	
	--select top(10) *
	--from staging.dbo.indx_index_data
	--where index_id=198 and data_timestamp >='2019-04-30' and granularity_item_id in (349, 350)
	--order by granularity_item_id, data_timestamp
	

---> 5. OOSH <---
-- 199	Total Out of Service Violations by State Highway Mile in 1000s	OOSH	M	INDX	Sum of Out of Service Violations per 1000 state miles
-- State only

	INSERT INTO Staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT a.data_value / (c.Lane_Miles / 1000) AS data_value, -- number of violations per 1000 miles 
		   a.data_timestamp, 
		   a.granularity_item_id, 
		   199 AS index_id
	FROM #ostate2 a --sum of oos violations
		 INNER JOIN -- to get states
	(
		SELECT granularity1, 
			   id
		FROM staging.dbo.indx_granularity_item
		WHERE granularity_level_id = 4
	) b ON a.granularity_item_id = b.id 
		 INNER JOIN Warehouse.dbo.Interstate_Miles_by_State c ON b.granularity1 = c.[state] -- to get interstate miles per state
	ORDER BY granularity_item_id, 
			 data_timestamp;
	
	--select top(10) *
	--from staging.dbo.indx_index_data
	--where index_id=199 and data_timestamp >'2019-04-30' and granularity_item_id in (349, 350)
	--order by granularity_item_id, data_timestamp
	

---> 6. OSVI <---
-- 216	Percent of Out of Service Violations	OSVI	M	PCNT	Total Out of Service Violations to Total Violations Percentage

-- USA
	INSERT INTO Staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT 
		a.data_value / b.data_value*100 AS data_value, -- oos violations/total violations
		a.data_timestamp, 
		1 AS granularity_item_id, 
		216 AS index_id
	FROM #OUSA1 a
		 INNER JOIN #USA1 b ON a.data_timestamp = b.data_timestamp
	ORDER BY data_timestamp

	
	--select top(10) *
	--from staging.dbo.indx_index_data
	--where index_id=216 and data_timestamp >'2019-04-30' and granularity_item_id=1
	--order by granularity_item_id, data_timestamp
	

-- By State
	INSERT INTO Staging.dbo.indx_index_data (data_value, data_timestamp, granularity_item_id, index_id)
	SELECT 
		CASE WHEN b.data_value=0 THEN 0 
		ELSE a.data_value / b.data_value*100 END AS data_value, -- number of oos violations per total violations. if no violations, then 0
		a.data_timestamp, 
		a.granularity_item_id, 
		216 AS index_id
	FROM #OSTATE2 a --OOS violations
		 INNER JOIN #STATE2 b ON a.data_timestamp = b.data_timestamp and a.granularity_item_id=b.granularity_item_id -- denominator- number of violations
    ORDER BY granularity_item_id, data_timestamp

	/*
	select top(10) *
	from staging.dbo.indx_index_data
	where index_id=216 and data_timestamp >'2019-04-30' and granularity_item_id in (349, 350)
	order by granularity_item_id, data_timestamp
	*/
-- drop all the temp tables
	DROP TABLE IF EXISTS #TempI;
	DROP TABLE IF EXISTS #usa1;
	DROP TABLE IF EXISTS #state1 ;
	DROP TABLE IF EXISTS #alldates;
	DROP TABLE IF EXISTS #state2;
	DROP TABLE IF EXISTS #ousa1;
	DROP TABLE IF EXISTS #ostate2;


-- CTE statement to keep only the most recent

	WITH dedup as (
		--declare @EndDate date = EOMonth(dateadd(mm, -6, getdate()))
		SELECT index_id,
			   data_timestamp,
			   granularity_item_id,
			   data_value,
			   ROW_NUMBER() OVER (PARTITION BY index_id, granularity_item_id, data_timestamp ORDER BY createdate DESC) as RN
		FROM Staging.dbo.indx_index_data
		WHERE index_id IN (197, 216, 199, 198, 598, 203) and data_timestamp >= @EndDate 
	)
	DELETE
	FROM dedup
	WHERE RN > 1




END


		/*
		SELECT top(100) index_id,
			   data_timestamp,
			   granularity_item_id,
			   data_value,
			   ROW_NUMBER() OVER (PARTITION BY index_id, granularity_item_id, data_timestamp ORDER BY createdate DESC) as RN
		FROM Staging.dbo.indx_index_data
		WHERE index_id IN (197, 216, 199, 198, 598, 203) and data_timestamp >= '2019-6-30' 

		select top(100)*
		from staging.dbo.indx_index_definition 
		WHERE id IN (197, 216, 199, 198, 598, 203)
		*/

		
		--SELECT index_id, granularity_item_id,
		--max(createdate)
		--FROM Staging.dbo.indx_index_data
		--WHERE index_id IN (197, 216, 199, 198, 598, 203)
		--group by index_id,granularity_item_id

		--select a.*, b.description
		--from 
		--(SELECT index_id,
		--	   data_timestamp,
		--	   granularity_item_id,
		--	   data_value,
		--	   createdate
		--FROM Staging.dbo.indx_index_data
		--WHERE index_id IN (197, 216, 199, 198, 598, 203) and data_timestamp >= '2019-6-30' ) a
		--left join staging.dbo.indx_granularity_item b
		--on a. granularity_item_id=b.id
		--order by index_id,			   
		--		granularity_item_id,				
		--		data_timestamp