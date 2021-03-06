
--Author:	Kate Fisher
--Date:		06August2019
--Purpose:	To put in FMCSA data from Aug2018-July2019 before the procedure takes over
--			Uses new assumptions.

/****** Script for SelectTopNRows command from SSMS  ******/




-- making sure the DOT_NUMBERS are only represented once per monthly transfer- Yes
SELECT asofdate, 
       COUNT(asofdate) AS count, 
       COUNT(DISTINCT(DOT_NUMBER)) AS dotct
FROM [Warehouse].[dbo].[FMCSA_Census]
GROUP BY asofdate
ORDER BY asofdate;

--------------------------------------
-- main dataset - total fleets - USA--
--------------------------------------
DROP TABLE IF EXISTS #all;
SELECT CAST(createdate AS DATE) AS asofdate, --because asofdate is no longer ingested
       [DOT_NUMBER], 
       act_stat, 
       CAST(adddate AS DATE) AS adddate, 
       CAST(createdate AS DATE) AS createdate, 
       CAST(mlg150 AS FLOAT) AS mlg150, 
       class, 
       household, 
       ICC_DOCKET_1_PREFIX, 
       ICC_DOCKET_2_PREFIX, 
       ICC_DOCKET_3_PREFIX, 
       FLEETSIZE, 
       CAST(owntract AS INT) AS owntract, 
       CAST(trmtract AS INT) AS trmtract, 
       CAST(trptract AS INT) AS trptract, 
       CAST(owntract AS INT) + CAST(trmtract AS INT) + CAST(trptract AS INT) AS tottract, 
       MCS150MILEAGEYEAR, 
       MLG151
       , -- I think this is MILETOT in the https://ask.fmcsa.dot.gov/app/mcmiscatalog/d_census_daEleDef 
       [CRRINTER], 
       [CRRHMINTRA], 
       [CRRINTRA], 
       [SHPINTER], 
       [SHPINTRA]
INTO #all
FROM [Warehouse].[dbo].[FMCSA_Census]
WHERE act_stat = 'A'
      AND (CAST([OWNTRACT] AS INT) > 0
           OR CAST([TRPTRACT] AS INT) > 0
           OR CAST([TRMTRACT] AS INT) > 0)
	  AND cast(mlg150 as float)>1;-- must have tractor. reported mileage must be >1

----------------------
---> FLEET COUNTS <---
----------------------

---> 1. Total Fleets (FCTC) <---
-- 587	Total Count of Fleets	FCTC (DUMMY=1343)
DROP TABLE IF EXISTS #data1;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 587 --NOTE: using 'distinct' is overkill, since there are already only 1 record per DOT_NUMBER per monthly file in FMCSA_census
INTO #data1
FROM #all
GROUP BY asofdate;


---> 2. Private Fleets (FCPF) <---
--903	Total Count of Private Fleets	FCPF (DUMMY=1353)
DROP TABLE IF EXISTS #data2;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 903
INTO #data2
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%C%' --class C means 'private', can't move household goods
GROUP BY asofdate;


--->  3. Intrastate <---
--909 as index_id, 909	Total Count of Intrastate Private Fleets	FCPFIS (DUMMY=1354)
DROP TABLE IF EXISTS #data3;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 909
INTO #data3
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

--SELECT COUNT(*)
--FROM #all
--WHERE ICC_DOCKET_1_PREFIX = 'FF'
--      OR ICC_DOCKET_2_PREFIX = 'FF'
--      OR ICC_DOCKET_3_PREFIX = 'FF';

---> 4. Interstate Private Fleets (FCPFMS) <---
--910 as index_id, 910	Total Count of Interstate Private Fleets	FCPFMS (DUMMY=1355)
DROP TABLE IF EXISTS #data4;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       910 AS index_id
	   --1355 AS index_id
INTO #data4
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%C%'  --class C means 'private', can't move household goods, and no interstate number
      AND (CRRINTER = 'A'
           OR SHPINTER = 'D' 
		   OR ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC') --interstate. technically MC is just 'for hire', but also checking prefix b/c MC means interstate and possible multiple classes
GROUP BY asofdate;

-- since there are some private fleets that don't have crrinter or shpinter, but do have ICC_DOCKET_PREFIX
/*select count(CRRINTER)
from #all
where (CRRINTER != 'A'
           AND SHPINTER != 'D' ) AND
		   (ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC')*/

---> 5. For Hire Fleets (FCFH) <---
--588 as index_id , 588	Total Count of Fleets Authorized For Hire	FCFH (DUMMY=1344)
DROP TABLE IF EXISTS #data5;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 588
INTO #data5
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
GROUP BY asofdate;

SELECT*
FROM #data5
order by data_timestamp

---> 6. Intrastate For Hire Fleets (FCFHIS) <---
--911 as index_id 911	Total Count of Intrastate For Hire Fleets	FCFHIS (DUMMY=1356)
DROP TABLE IF EXISTS #data6;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 911
INTO #data6
FROM #all 
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
DROP TABLE IF EXISTS #data7;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 913
INTO #data7
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	  AND (ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC') -- use MC for-hire inter/intra designation
      /*OR (CRRINTER = 'A'
           OR SHPINTER = 'D') --interstate*/
GROUP BY asofdate;


---> 8. New Fleets Authorized For Hire  <---
-- 848	Total Count of New Fleets Authorized For Hire	FCFHN - younger than 18 months (DUMMY=1351)
DROP TABLE IF EXISTS #data8;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 848
INTO #data8
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
      AND DATEDIFF(Month, adddate, asofdate) < 18 --adddate must be within 18 months of asofdate 
GROUP BY asofdate;



---> 9. 849	Total Count of Old Fleets Authorized For Hire	FCFHO <---
-- 849	Total Count of Old Fleets Authorized For Hire	FCFHO  - older than/= to 18 months (DUMMY=1352)
DROP TABLE IF EXISTS #data9;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 849
INTO #data9
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
      AND DATEDIFF(Month, adddate, asofdate) >= 18 --adddate must be >= 18 months before asofdate 
GROUP BY asofdate;


---> 10. Total Fleets with 1 - 6 Power Unit <---
-- 591	Total Count of Fleets with 1 - 6 Power Units	FCTCO (DUMMY=1345)
DROP TABLE IF EXISTS #data10;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 591 --591	Total Count of Fleets with 1 - 6 Power Units	FCTCO
INTO #data10
FROM #all 
WHERE FLEETSIZE IN('A', 'B', 'C')
GROUP BY asofdate;


-- 11. Total Count of Fleets with7 - 11 Power Units --
-- 592	Total Count of Fleets with 7 to 11 Power Units	FCTCS (DUMMY=1346)
DROP TABLE IF EXISTS #data11;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 592
INTO #data11
FROM #all 
WHERE FLEETSIZE IN('D', 'E')
GROUP BY asofdate;


-- 12. Total Count of Fleets with 12 - 19 Power Units
-- 751	Total Count of Fleets With 12 - 19 Power Units	FCTCT (DUMMY=1350)
DROP TABLE IF EXISTS #data12;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 751
INTO #data12
FROM #all 
WHERE FLEETSIZE IN('F', 'G', 'H')
GROUP BY asofdate;

-- 13. Total Count of Fleets with 20 - 100 Power Units
-- 593	Total Count of Fleets with 20 to 100 Power Units	FCTCM (DUMMY=1347)
DROP TABLE IF EXISTS #data13;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 593
INTO #data13
FROM #all 
WHERE FLEETSIZE IN('I', 'J', 'K', 'L', 'M', 'N', 'O', 'P')
GROUP BY asofdate;


-- 14. Total Count of Fleets with 101 - 999 Power Units
-- 594	Total Count of Fleets with 101 to 999 Power Units	FCTCL (DUMMY=1348)
DROP TABLE IF EXISTS #data14;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 594
INTO #data14
FROM #all 
WHERE FLEETSIZE IN('Q', 'R', 'S', 'T', 'U')
GROUP BY asofdate;


-- 15. Total Count of Fleets with 1000+ Power Units
-- 595	Total Count of Fleets with 1000+ Power Units	FCTCE (DUMMY=1349)
DROP TABLE IF EXISTS #data15;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       COUNT(DISTINCT(DOT_NUMBER)) AS data_value, 
       granularity_item_id = 1, 
       index_id = 595
INTO #data15
FROM #all 
WHERE FLEETSIZE IN('V', 'W', 'X', 'Y', 'Z')
GROUP BY asofdate;




DROP TABLE IF EXISTS #final;
CREATE TABLE #final
(data_timestamp      DATE, 
 data_value          INT, 
 granularity_item_id INT, 
 index_id            INT
);
INSERT INTO #Final
       SELECT *
       FROM #data1
       UNION
       SELECT *
       FROM #data2
       UNION
       SELECT *
       FROM #data3
       UNION
       SELECT *
       FROM #data4
       UNION
       SELECT *
       FROM #data5
       UNION
       SELECT *
       FROM #data6
       UNION
       SELECT *
       FROM #data7
       UNION
       SELECT *
       FROM #data8
       UNION
       SELECT *
       FROM #data9
       UNION
       SELECT *
       FROM #data10
       UNION
       SELECT *
       FROM #data11
       UNION
       SELECT *
       FROM #data12
       UNION
       SELECT *
       FROM #data13
       UNION
       SELECT *
       FROM #data14
       UNION
       SELECT *
       FROM #data15;

-- fill in 2018-09-12/2018-11 average for 2018-10-09

drop table if exists #oct
select *
into #OCT
from #final
where data_timestamp='2018-09-12' or data_timestamp like '2018-11%'
order by index_id, data_timestamp
select *
from #oct
order by index_id, data_timestamp

-- taking average
drop table if exists #oct2
select index_id, granularity_item_id, sum(data_value)/2 as data_value, data_timestamp='2018-10-09'
into #oct2
from #OCT
group by index_id, granularity_item_id


-- insert average for october (sep, nov average)
--insert into staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)
	SELECT data_timestamp, data_value, granularity_item_id, index_id
	FROM #OCT2



-- to replace in indx_index_data
	--INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)
	SELECT *
	FROM #final

	--look at it
SELECT a.*, 
       b.ticker, 
       b.index_name
FROM #final a
     INNER JOIN [Staging].[dbo].[indx_index_definition] b ON a.index_id = b.id
ORDER BY index_id, 
         data_timestamp;


--INSERT INTO Warehouse.dbo.cots_fmcsa_comparison_kf (data_timestamp, data_value, granularity_item_id, index_id, ticker, index_name, [source])
 select a.*, 
       b.ticker, 
       b.index_name,
	   'fmcsa' as [source]
from #final a
     INNER JOIN [Staging].[dbo].[indx_index_definition] b ON a.index_id = b.id




------------------------
---> TRACTOR COUNTS <---
------------------------
---> 1. Total Fleets (FCTC) <---
-- Total Count of Tractors	
DROP TABLE IF EXISTS #data1;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1366 --NOTE: summing tottract, since there are already only 1 record per DOT_NUMBER per monthly file in FMCSA_census and don't need to account for distinct DOT_numbers
INTO #data1
FROM #all
GROUP BY asofdate;
SELECT *
FROM #data1
ORDER BY data_timestamp;

---> 2. Private Fleets (FCPF) <---
--1376	Total Count of Private Tractors	TCPF
DROP TABLE IF EXISTS #data2;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1376
INTO #data2
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%C%' --class C means 'private', can't move household goods
GROUP BY asofdate;
SELECT *
FROM #data2
ORDER BY data_timestamp;

--->  3. Intrastate <---
--1377	Total Count of Intrastate Private Tractors	TCPFIS
DROP TABLE IF EXISTS #data3;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1377
INTO #data3
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

SELECT *
FROM #data3
ORDER BY data_timestamp;

---> 4. Interstate Private Fleets (FCPFMS) <---
--1378	Total Count of Interstate Private Tractors	TCPFMS
DROP TABLE IF EXISTS #data4;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       1378 AS index_id
INTO #data4
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%C%'  --class C means 'private', can't move household goods, and no interstate number
      AND (CRRINTER = 'A'
           OR SHPINTER = 'D' 
		   OR ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC') --interstate. technically MC is just 'for hire', but also checking prefix b/c MC means interstate and possible multiple classes
GROUP BY asofdate;
SELECT *
FROM #data4
ORDER BY data_timestamp;

---> 5. For Hire Fleets (FCFH) <---
--1367	Total Count of Tractors Authorized For Hire	TCFH
DROP TABLE IF EXISTS #data5;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1367
INTO #data5
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
GROUP BY asofdate;
SELECT *
FROM #data5
ORDER BY data_timestamp;

---> 6. Intrastate For Hire Fleets (FCFHIS) <---
--1379	Total Count of Intrastate For Hire Tractors	TCFHIS
DROP TABLE IF EXISTS #data6;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1379
INTO #data6
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
SELECT *
FROM #data6
ORDER BY data_timestamp;

---- lack of all evidence of interstate = intrastate? assuming so
--select count(household)
--from #all
--where HOUSEHOLD != 'X'
--      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
--	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
--	  AND ICC_DOCKET_1_PREFIX != 'MC' AND ICC_DOCKET_2_PREFIX != 'MC' AND ICC_DOCKET_3_PREFIX != 'MC' 
--	  AND CRRINTER != 'A'
--      AND SHPINTER != 'D'

--select count(household)
--from #all
--where HOUSEHOLD != 'X'
--      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
--	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
--	  AND ICC_DOCKET_1_PREFIX != 'MC' AND ICC_DOCKET_2_PREFIX != 'MC' AND ICC_DOCKET_3_PREFIX != 'MC' 

--select count(household)
--from #all
--where HOUSEHOLD != 'X'
--      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
--	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
--	  AND (CRRHMINTRA = 'B'
--           OR CRRINTRA = 'C'
--           OR SHPINTRA = 'E')



---> 7. Interstate For Hire Fleets (FCFHMS) <---
-- 1380	Total Count of Interstate For Hire Tractors	TCFHMS
DROP TABLE IF EXISTS #data7;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1380
INTO #data7
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	  AND (ICC_DOCKET_1_PREFIX = 'MC' OR ICC_DOCKET_2_PREFIX = 'MC' OR ICC_DOCKET_3_PREFIX = 'MC') -- use MC for-hire inter/intra designation
      /*OR (CRRINTER = 'A'
           OR SHPINTER = 'D') --interstate*/
GROUP BY asofdate;
SELECT *
FROM #data7
ORDER BY data_timestamp;

---> 8. New Fleets Authorized For Hire  <---
-- 1374	Total Count of New Tractors Authorized For Hire	TCFHN - younger than 18 months
DROP TABLE IF EXISTS #data8;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1374
INTO #data8
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
      AND DATEDIFF(Month, adddate, asofdate) < 18 --adddate must be within 18 months of asofdate 
GROUP BY asofdate;
SELECT *
FROM #data8
ORDER BY data_timestamp;

---> 9. Total Count of Old Fleets Authorized For Hire	FCFHO <---
-- 1375	Total Count of Old Tractors Authorized For Hire	TCFHO  - older than/= to 18 months
DROP TABLE IF EXISTS #data9;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1375
INTO #data9
FROM #all 
WHERE HOUSEHOLD != 'X'
      AND (class) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (class) NOT LIKE '%C%' -- if it is for hire, it can't also be private
      AND DATEDIFF(Month, adddate, asofdate) >= 18 --adddate must be >= 18 months before asofdate 
GROUP BY asofdate;
SELECT *
FROM #data9
ORDER BY data_timestamp;

---> 10. Total Fleets with 1 - 6 Power Unit <---
-- 1368	Total Count of Tractors with 1 - 6 Power Units
DROP TABLE IF EXISTS #data10;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1368
INTO #data10
FROM #all 
WHERE FLEETSIZE IN('A', 'B', 'C')
GROUP BY asofdate;
SELECT *
FROM #data10
ORDER BY data_timestamp;

-- 11. Total Count of Fleets with 6 - 11 Power Units --
-- 1369	Total Count of Tractors with 7 to 11 Power Units	TCTCS
DROP TABLE IF EXISTS #data11;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1369
INTO #data11
FROM #all 
WHERE FLEETSIZE IN('D', 'E')
GROUP BY asofdate;
SELECT *
FROM #data11
ORDER BY data_timestamp;

-- 12. Total Count of Fleets with 12 - 19 Power Units
-- 1373	Total Count of Tractors With 12 - 19 Power Units	TCTCT
DROP TABLE IF EXISTS #data12;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1373
INTO #data12
FROM #all 
WHERE FLEETSIZE IN('F', 'G', 'H')
GROUP BY asofdate;
SELECT *
FROM #data12
ORDER BY data_timestamp;

-- 13. Total Count of Fleets with 20 - 100 Power Units
-- 1370	Total Count of Tractors with 20 to 100 Power Units 	TCTCM
DROP TABLE IF EXISTS #data13;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1370
INTO #data13
FROM #all 
WHERE FLEETSIZE IN('I', 'J', 'K', 'L', 'M', 'N', 'O', 'P')
GROUP BY asofdate;
SELECT *
FROM #data13
ORDER BY data_timestamp;

-- 14. Total Count of Fleets with 101 - 999 Power Units
-- 1371	Total Count of Tractors with 101 to 999 Power Units 	TCTCL
DROP TABLE IF EXISTS #data14;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1371
INTO #data14
FROM #all 
WHERE FLEETSIZE IN('Q', 'R', 'S', 'T', 'U')
GROUP BY asofdate;
SELECT *
FROM #data14
ORDER BY data_timestamp;

-- 15. Total Count of Fleets with 1000+ Power Units
-- 1372	Total Count of Tractors with 1000+ Power Units	TCTCE
DROP TABLE IF EXISTS #data15;
SELECT CAST(asofdate AS DATE) AS data_timestamp, 
       SUM(tottract) AS data_value, 
       granularity_item_id = 1, 
       index_id = 1372
INTO #data15
FROM #all 
WHERE FLEETSIZE IN('V', 'W', 'X', 'Y', 'Z')
GROUP BY asofdate;
SELECT *
FROM #data15
ORDER BY data_timestamp;
-- put all into one table
DROP TABLE IF EXISTS #tract;
CREATE TABLE #tract
(data_timestamp      DATE, 
 data_value          INT, 
 granularity_item_id INT, 
 index_id            INT
);
INSERT INTO #tract
       SELECT *
       FROM #data1
       UNION
       SELECT *
       FROM #data2
       UNION
       SELECT *
       FROM #data3
       UNION
       SELECT *
       FROM #data4
       UNION
       SELECT *
       FROM #data5
       UNION
       SELECT *
       FROM #data6
       UNION
       SELECT *
       FROM #data7
       UNION
       SELECT *
       FROM #data8
       UNION
       SELECT *
       FROM #data9
       UNION
       SELECT *
       FROM #data10
       UNION
       SELECT *
       FROM #data11
       UNION
       SELECT *
       FROM #data12
       UNION
       SELECT *
       FROM #data13
       UNION
       SELECT *
       FROM #data14
       UNION
       SELECT *
       FROM #data15;

-- fill in 2018-09-12/2018-11 average for 2018-10-09

drop table if exists #oct
select *
into #OCT
from #tract
where data_timestamp='2018-09-12' or data_timestamp like '2018-11%'
order by index_id, data_timestamp

-- taking average
drop table if exists #oct2
select index_id, granularity_item_id, sum(data_value)/2 as data_value, data_timestamp='2018-10-09'
into #oct2
from #OCT
group by index_id, granularity_item_id

-- insert average for october
--insert into staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)
	SELECT data_timestamp, data_value, granularity_item_id, index_id
	FROM #OCT2

-- to replace in indx_index_data
--	INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)
	SELECT *
	FROM #tract

-- look at it
SELECT a.*, 
       b.ticker, 
       b.index_name
FROM #tract a
     INNER JOIN [Staging].[dbo].[indx_index_definition] b ON a.index_id = b.id
ORDER BY index_id, 
         data_timestamp;

-- tickers that are in production already
SELECT *
FROM [Staging].[dbo].[indx_index_definition]
where index_name like '%tractors%' and index_name NOT LIKE '%per 1000 Tractors%'

select top(100) a.*, b.ticker,b.index_name
from staging.dbo.indx_index_data a
inner join (select id,ticker,index_name
FROM [Staging].[dbo].[indx_index_definition] 
WHERE (description LIKE '%Fleets%'
      or index_name  LIKE '%Tractors%')
      and index_name NOT LIKE '%per 1000 Tractors%') b
	  on a.index_id=b.id

/*
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Fleets Authorized For Hire', 
      description = 'Monthly Total Count of Tractors from Fleets Authorized For Hire Reported to FMCSA'
WHERE ID = 1367;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Fleets with 1 - 6 Power Units', 
      description = 'Monthly Total Count of Tractors from Fleets with 1 - 6 Power Units Reported to FMCSA'
WHERE ID = 1368;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Fleets with 7 to 11 Power Units', 
      description = 'Monthly Total Count of Tractors from Fleets with 7 to 11 Power Units Reported to FMCSA'
WHERE ID = 1369;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Fleets with 20 to 100 Power Units', 
      description = 'Monthly Total Count of Tractors from Fleets with 20 to 100 Power Units Reported to FMCSA'
WHERE ID = 1370;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Fleets with 101 to 999 Power Units', 
      description = 'Monthly Total Count of Tractors from Fleets with 101 to 999 Power Units Reported to FMCSA'
WHERE ID = 1371;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Fleets with 1000+ Power Units', 
      description = 'Monthly Total Count of Tractors from Fleets with 1000+ Power Units Reported to FMCSA'
WHERE ID = 1372;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Fleets With 12 - 19 Power Units', 
      description = 'Monthly Total Count of Tractors from Fleets With 12 - 19 Power Units Reported to FMCSA'
WHERE ID = 1373;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from New Fleets Authorized For Hire', 
      description = 'Monthly Total Count of Tractors from Fleets Younger than 18 Months Authorized For Hire Reported to FMCSA'
WHERE ID = 1374;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Old Fleets Authorized For Hire', 
      description = 'Monthly Total Count of Tractors from Fleets 18 Months or Older Authorized For Hire Reported to FMCSA'
WHERE ID = 1375;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Private Fleets', 
      description = 'Monthly Total Count of Tractors from Private Fleets Reported to FMCSA'
WHERE ID = 1376;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Intrastate Private Fleets', 
      description = 'Monthly Total Count of Tractors from Intrastate Private Fleets Reported to FMCSA'
WHERE ID = 1377;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Interstate Private Fleets', 
      description = 'Monthly Total Count of Tractors from Interstate Private Fleets Reported to FMCSA'
WHERE ID = 1378;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Intrastate For Hire Fleets', 
      description = 'Monthly Total Count of Tractors from Intrastate For Hire Fleets Reported to FMCSA'
WHERE ID = 1379;
UPDATE [Staging].[dbo].[indx_index_definition]
  SET 
      index_name = 'Total Count of Tractors from Interstate For Hire Fleets', 
      description = 'Monthly Total Count of Tractors from Interstate For Hire Fleets Reported to FMCSA'
WHERE ID = 1380;
*/
