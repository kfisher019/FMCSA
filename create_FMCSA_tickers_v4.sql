USE [Staging]
GO
/****** Object:  StoredProcedure [dbo].[create_FMCSA_Census_Tickers]    Script Date: 9/6/2019 10:35:34 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- EXEC [dbo].[create_FMCSA_Census_Tickers]
-- Author: Kate Fisher
-- Date: Aug 05,2019
-- Purpose: count fleets and number of tractors in FMCSA data on a monthly basis. 

ALTER procedure [dbo].[create_FMCSA_Census_Tickers]

AS

	BEGIN 



-- make sure asofdate is > the most recent one in indx_index_data


	DROP TABLE IF EXISTS #all;

	SELECT CAST( createdate AS DATE ) AS asofdate, --since asofdate wasn't included
		   DOT_NUMBER, 
		   act_stat, 
		   CAST( adddate AS DATE ) AS adddate, 
		   CAST( createdate AS DATE ) AS createdate, 
		   class, 
		   household, 
		   ICC_DOCKET_1_PREFIX, 
		   ICC_DOCKET_2_PREFIX, 
		   ICC_DOCKET_3_PREFIX, 
		   FLEETSIZE, 
		   CAST( owntract AS INT ) AS owntract, 
		   CAST( trmtract AS INT ) AS trmtract, 
		   CAST( trptract AS INT ) AS trptract, 
		   CAST( owntract AS INT )+CAST( trmtract AS INT )+CAST( trptract AS INT ) AS tottract, 
		   CAST( mlg150 AS FLOAT ) AS mlg150, 
		   MCS150MILEAGEYEAR, 
		   MLG151, -- I think this is MILETOT in the https://ask.fmcsa.dot.gov/app/mcmiscatalog/d_census_daEleDef 
		   CRRINTER, 
		   CRRHMINTRA, 
		   CRRINTRA, 
		   SHPINTER, 
		   SHPINTRA, 
		   b.maxdt
	INTO #all
	FROM Warehouse.dbo.FMCSA_Census 
	AS a
	LEFT JOIN
	(
	  SELECT MAX( data_timestamp )
	  AS maxdt
	  FROM staging.dbo.indx_index_data
	  WHERE index_id=587-- dummy: 1343
	)
	AS b -- get max date that already exists in indx_index_data, and take only new records after that date
	ON a.createdate>b.maxdt 
	WHERE a.createdate>b.maxdt 
		  AND act_stat='A'
		  AND (CAST( OWNTRACT AS INT )>0
			   OR CAST( TRPTRACT AS INT )>0
			   OR CAST( TRMTRACT AS INT )>0)
	      AND cast(mlg150 as float)>1;-- must have tractor and reported mileage over 1


----------------------
---> FLEET COUNTS <---
----------------------

---> 1. Total Fleets (FCTC) <---
-- 587	Total Count of Fleets	FCTC (DUMMY=1343)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 587 --NOTE: using 'distinct' is overkill, since there are already only 1 record per DOT_NUMBER per monthly file in FMCSA_census
	FROM #all
	GROUP BY asofdate;

	
---> 2. Private Fleets (FCPF) <---
--903	Total Count of Private Fleets	FCPF (DUMMY=1353)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 903
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%C%' --class C means 'private', can't move household goods
	GROUP BY asofdate;


--->  3. Intrastate <---
--909 as index_id, 909	Total Count of Intrastate Private Fleets	FCPFIS (DUMMY=1354)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 909
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%C%' -- and ICC_DOCKET_1_PREFIX != 'MC' and ICC_DOCKET_2_PREFIX != 'MC' and ICC_DOCKET_3_PREFIX != 'MC'  --class C means 'private', can't move household goods, and no interstate number
		  AND (CRRHMINTRA = 'B'
			   OR CRRINTRA = 'C'
			   OR SHPINTRA = 'E')-- MC numbers are only 'for hire' so using these variables for intrastate, but also mandating not MC prefix (which is evidence of interstate)
			   and ICC_DOCKET_1_PREFIX != 'MC' and ICC_DOCKET_2_PREFIX != 'MC' and ICC_DOCKET_3_PREFIX != 'MC' 
	GROUP BY asofdate;
--MX means Mexico-based Carriers for Motor Carrier Authority
--FF means Freight Forwarder Authority
--P means Motor Passenger Carrier Authority
--NNA means Non-North America-Domiciled Motor Carriers
--MC means Motor Carrier Authority?



---> 4. Interstate Private Fleets (FCPFMS) <---
--910 as index_id, 910	Total Count of Interstate Private Fleets	FCPFMS (DUMMY=1355)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   910 AS index_id
		   --1355 AS index_id
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%C%'  --class C means 'private', can't move household goods, and no interstate number
		  AND (CRRINTER = 'A'
			   OR SHPINTER = 'D' 
			   OR ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC') --interstate. technically MC is just 'for hire', but also checking prefix b/c MC means interstate and possible multiple classes
	GROUP BY asofdate;


---> 5. For Hire Fleets (FCFH) <---
--588 as index_id , 588	Total Count of Fleets Authorized For Hire	FCFH (DUMMY=1344)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 588
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	GROUP BY asofdate;


---> 6. Intrastate For Hire Fleets (FCFHIS) <---
--911 as index_id 911	Total Count of Intrastate For Hire Fleets	FCFHIS (DUMMY=1356)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 911
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		  AND ICC_DOCKET_1_PREFIX != 'MC' AND ICC_DOCKET_2_PREFIX != 'MC' AND ICC_DOCKET_3_PREFIX != 'MC' -- use MC for-hire inter/intra designation - no MC prefix means intrastate
		  AND CRRINTER != 'A' -- also not allowing them to be registered as interstate carrier
		  AND SHPINTER != 'D' -- also not allowing them to be registered as interstate shipper
		 /* AND (CRRHMINTRA = 'B'
			   OR CRRINTRA = 'C'
			   OR SHPINTRA = 'E')-- assuming these are intra, perhaps better assumption than ICC DOCKET? Could also mandate ICC_DOCKETS can't be 'MC'*/
	GROUP BY asofdate;


---> 7. Interstate For Hire Fleets (FCFHMS) <---
-- 913	Total Count of Interstate For Hire Fleets	FCFHMS (DUMMY=1357)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 913
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		  AND (ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC') -- use MC for-hire inter/intra designation
		  /*OR (CRRINTER = 'A'
			   OR SHPINTER = 'D') --interstate*/
	GROUP BY asofdate;


---> 8. New Fleets Authorized For Hire  <---
-- 848	Total Count of New Fleets Authorized For Hire	FCFHN - younger than 18 months (DUMMY=1351)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 848
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		  AND DATEDIFF(Month, adddate, asofdate) < 18 --adddate must be within 18 months of asofdate 
	GROUP BY asofdate;



---> 9. 849	Total Count of Old Fleets Authorized For Hire	FCFHO <---
-- 849	Total Count of Old Fleets Authorized For Hire	FCFHO  - older than/= to 18 months (DUMMY=1352)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 849
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		  AND DATEDIFF(Month, adddate, asofdate) >= 18 --adddate must be >= 18 months before asofdate 
	GROUP BY asofdate;


---> 10. Total Fleets with 1 - 6 Power Unit <---
-- 591	Total Count of Fleets with 1 - 6 Power Units	FCTCO (DUMMY=1345)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 591 --591	Total Count of Fleets with 1 - 6 Power Units	FCTCO
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE FLEETSIZE IN('A', 'B', 'C')
	GROUP BY asofdate;


-- 11. Total Count of Fleets with7 - 11 Power Units --
-- 592	Total Count of Fleets with 7 to 11 Power Units	FCTCS (DUMMY=1346)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 592
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE FLEETSIZE IN('D', 'E')
	GROUP BY asofdate;


-- 12. Total Count of Fleets with 12 - 19 Power Units
-- 751	Total Count of Fleets With 12 - 19 Power Units	FCTCT (DUMMY=1350)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 751
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE FLEETSIZE IN('F', 'G', 'H')
	GROUP BY asofdate;

-- 13. Total Count of Fleets with 20 - 100 Power Units
-- 593	Total Count of Fleets with 20 to 100 Power Units	FCTCM (DUMMY=1347)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 593
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE FLEETSIZE IN('I', 'J', 'K', 'L', 'M', 'N', 'O', 'P')
	GROUP BY asofdate;


-- 14. Total Count of Fleets with 101 - 999 Power Units
-- 594	Total Count of Fleets with 101 to 999 Power Units	FCTCL (DUMMY=1348)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 594
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE FLEETSIZE IN('Q', 'R', 'S', 'T', 'U')
	GROUP BY asofdate;


-- 15. Total Count of Fleets with 1000+ Power Units
-- 595	Total Count of Fleets with 1000+ Power Units	FCTCE (DUMMY=1349)
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 595
	FROM #all -- this already filters for act_stat='A' and  (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor. took out mlg150 bc unreliable
	WHERE FLEETSIZE IN('V', 'W', 'X', 'Y', 'Z')
	GROUP BY asofdate;


---> TRACTOR COUNTS <---

---> 1. Total Fleets (FCTC) <---
-- Total Count of Tractors	
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1366 --NOTE: summing tottract, since there are already only 1 record per DOT_NUMBER per monthly file in FMCSA_census and don't need to account for distinct DOT_numbers
	FROM #all
	GROUP BY asofdate;

---> 2. Private Fleets (FCPF) <---
--1376	Total Count of Private Tractors	TCPF
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1376
	FROM #all 
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%C%' --class C means 'private', can't move household goods
	GROUP BY asofdate;


--->  3. Intrastate <---
--1377	Total Count of Intrastate Private Tractors	TCPFIS
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1377
	FROM #all 
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%C%' -- and ICC_DOCKET_1_PREFIX != 'MC' and ICC_DOCKET_2_PREFIX != 'MC' and ICC_DOCKET_3_PREFIX != 'MC'  --class C means 'private', can't move household goods, and no interstate number
		  AND (CRRHMINTRA = 'B'
			   OR CRRINTRA = 'C'
			   OR SHPINTRA = 'E')-- MC numbers are only 'for hire' so using these variables for intrastate, but also mandating not MC prefix (which is evidence of interstate)
			   and ICC_DOCKET_1_PREFIX != 'MC' and ICC_DOCKET_2_PREFIX != 'MC' and ICC_DOCKET_3_PREFIX != 'MC' 
	GROUP BY asofdate;
--MX means Mexico-based Carriers for Motor Carrier Authority
--FF means Freight Forwarder Authority
--P means Motor Passenger Carrier Authority
--NNA means Non-North America-Domiciled Motor Carriers
--MC means Motor Carrier Authority?


---> 4. Interstate Private Fleets (FCPFMS) <---
--1378	Total Count of Interstate Private Tractors	TCPFMS
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   1378 AS index_id
	FROM #all 
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%C%'  --class C means 'private', can't move household goods, and no interstate number
		  AND (CRRINTER = 'A'
			   OR SHPINTER = 'D' 
			   OR ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC') --interstate. technically MC is just 'for hire', but also checking prefix b/c MC means interstate and possible multiple classes
	GROUP BY asofdate;

---> 5. For Hire Fleets (FCFH) <---
--1367	Total Count of Tractors Authorized For Hire	TCFH
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1367
	FROM #all 
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	GROUP BY asofdate;

---> 6. Intrastate For Hire Fleets (FCFHIS) <---
--1379	Total Count of Intrastate For Hire Tractors	TCFHIS
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1379
	FROM #all 
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		  AND ICC_DOCKET_1_PREFIX != 'MC' AND ICC_DOCKET_2_PREFIX != 'MC' AND ICC_DOCKET_3_PREFIX != 'MC' -- use MC for-hire inter/intra designation - no MC prefix means intrastate
		  AND CRRINTER != 'A' -- also not allowing them to be registered as interstate carrier
		  AND SHPINTER != 'D' -- also not allowing them to be registered as interstate shipper
		  /*AND (CRRHMINTRA = 'B'
			   OR CRRINTRA = 'C'
			   OR SHPINTRA = 'E') other evidence of intra- not using. Assuming no evidence of interstate, means it is intra*/
	GROUP BY asofdate;


---> 7. Interstate For Hire Fleets (FCFHMS) <---
-- 1380	Total Count of Interstate For Hire Tractors	TCFHMS
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1380
	FROM #all 
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		  AND (ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC') -- use MC for-hire inter/intra designation
		  /*OR (CRRINTER = 'A'
			   OR SHPINTER = 'D') --interstate*/
	GROUP BY asofdate;


---> 8. New Fleets Authorized For Hire  <---
-- 1374	Total Count of New Tractors Authorized For Hire	TCFHN - younger than 18 months
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1374
	FROM #all 
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		  AND DATEDIFF(Month, adddate, asofdate) < 18 --adddate must be within 18 months of asofdate 
	GROUP BY asofdate;


---> 9. Total Count of Old Fleets Authorized For Hire	FCFHO <---
-- 1375	Total Count of Old Tractors Authorized For Hire	TCFHO  - older than/= to 18 months
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1375
	FROM #all 
	WHERE HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		  AND DATEDIFF(Month, adddate, asofdate) >= 18 --adddate must be >= 18 months before asofdate 
	GROUP BY asofdate;

---> 10. Total Fleets with 1 - 6 Power Unit <---
-- 1368	Total Count of Tractors with 1 - 6 Power Units
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1368
	FROM #all 
	WHERE FLEETSIZE IN('A', 'B', 'C')
	GROUP BY asofdate;


-- 11. Total Count of Fleets with 6 - 11 Power Units --
-- 1369	Total Count of Tractors with 7 to 11 Power Units	TCTCS
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1369
	FROM #all 
	WHERE FLEETSIZE IN('D', 'E')
	GROUP BY asofdate;


-- 12. Total Count of Fleets with 12 - 19 Power Units
-- 1373	Total Count of Tractors With 12 - 19 Power Units	TCTCT
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1373
	FROM #all 
	WHERE FLEETSIZE IN('F', 'G', 'H')
	GROUP BY asofdate;


-- 13. Total Count of Fleets with 20 - 100 Power Units
-- 1370	Total Count of Tractors with 20 to 100 Power Units 	TCTCM
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1370
	FROM #all 
	WHERE FLEETSIZE IN('I', 'J', 'K', 'L', 'M', 'N', 'O', 'P')
	GROUP BY asofdate;

-- 14. Total Count of Fleets with 101 - 999 Power Units
-- 1371	Total Count of Tractors with 101 to 999 Power Units 	TCTCL
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1371
	FROM #all 
	WHERE FLEETSIZE IN('Q', 'R', 'S', 'T', 'U')
	GROUP BY asofdate;


-- 15. Total Count of Fleets with 1000+ Power Units
-- 1372	Total Count of Tractors with 1000+ Power Units	TCTCE
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   SUM(tottract) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1372
	FROM #all 
	WHERE FLEETSIZE IN('V', 'W', 'X', 'Y', 'Z')
	GROUP BY asofdate;

-----------------------------------------
---> FLEET COUNTS by size - for hire <---
-----------------------------------------
---> 10. Total Fleets with 1 - 6 Power Unit <---
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1503
	FROM #all 
	WHERE FLEETSIZE IN('A', 'B', 'C')
		  AND HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	GROUP BY asofdate;


-- 11. Total Count of Fleets with7 - 11 Power Units --
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1504
	FROM #all 
	WHERE FLEETSIZE IN('D', 'E')
		  AND HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	GROUP BY asofdate;


-- 12. Total Count of Fleets with 12 - 19 Power Units
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1505
	FROM #all 
	WHERE FLEETSIZE IN('F', 'G', 'H')
		  AND HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	GROUP BY asofdate;

-- 13. Total Count of Fleets with 20 - 100 Power Units
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1502
	FROM #all 
	WHERE FLEETSIZE IN('I', 'J', 'K', 'L', 'M', 'N', 'O', 'P')
		  AND HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	GROUP BY asofdate;


-- 14. Total Count of Fleets with 101 - 999 Power Units
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1501
	FROM #all 
	WHERE FLEETSIZE IN('Q', 'R', 'S', 'T', 'U')
		  AND HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	GROUP BY asofdate;


-- 15. Total Count of Fleets with 1000+ Power Units
	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)	
	SELECT CAST(asofdate AS DATE) AS data_timestamp, 
		   COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
		   granularity_item_id = 1, 
		   index_id = 1500
	FROM #all 
	WHERE FLEETSIZE IN('V', 'W', 'X', 'Y', 'Z')
		  AND HOUSEHOLD != 'X'
		  AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
		  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	GROUP BY asofdate;



	-- drop temp table
	DROP TABLE IF EXISTS #all

	END

	--select data_timestamp, data_value, granularity_item_id, index_id
	--from staging.dbo.indx_index_data
	--where index_id in (587,903,909,910,588,911,913,848,849,591,592,751,593,594,595,
	--1366,1376,1377,1378,1367,1379,1380,1374,1375,1368,1369,1373,1370,1371,1372,1503,1504,1505,1502,1501,1500) and data_timestamp >='2019-09-01'
	--order by index_id, data_timestamp

	