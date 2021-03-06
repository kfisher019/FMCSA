
-- Author: Kate Fisher
-- Date: Sep 16,2019
-- Purpose: count fleets and number of tractors in FMCSA data on a monthly basis- cots_census_history

Drop table if exists #chg
SELECT [id], [census_num]
		,[start_date]
		,[end_date]
		,[ntract]
		,[new_fleetsize_2] 
		,[new_mlg150_2]
		,[new_owntract_2]
		,[new_trmtract_2]
		,[new_trptract_2]
		,[new_act_stat_2]
		,[new_class_2]
		,[new_iccdocket1_2]
		,[new_iccdocket2_2]
		,[new_iccdocket3_2]
		,[new_household_2]
		,[new_crrinter_2]
		,[new_crrhmintra_2]
		,[new_crrintra_2]
		,[new_shipinter_2]
		,[new_shipintra_2]
		,case when [start_date]>[end_date] then [end_date] --50996 - these are due to 2 entries with same updateCHG in cots file, I will change start_date to end_date 
		else [start_date]
		end as [start_date2]
	   ,cast([adddate] as date) as [adddate]
  into #chg
  FROM [Warehouse].[dbo].[cots_census_changes_all_kf_v2]
  where act_stat='A' and new_mlg150_2 not in ('0','1','') and ntract >0 --same filtering as before (must be active, have recorded mileage and have at least 1 tractor)

-- add the IDs that are not in the cots_census_changes_all_kf_v2 file

DROP TABLE IF EXISTS #rest;
SELECT [id], a.census_num, 
	   case when act_stat='I' then CAST(chngdate AS DATE)
       else CAST(adddate AS DATE) END AS start_date2, 
       TRY_CAST(createdate AS DATE) AS end_date, -- there is one date that is characters and not a real date, hence 'try_cast'
       CAST(owntract AS INT) + CAST(trmtract AS INT) + CAST(trptract AS INT) AS ntract, 
       RTRIM(fleetsize) AS new_fleetsize_2, 
       CAST(mlg150 AS FLOAT) AS new_mlg150_2, 
       class as new_class_2, 
       household as new_household_2, 
       iccdocket1 as new_iccdocket1_2, 
       iccdocket2 as new_iccdocket2_2, 
       iccdocket3 as new_iccdocket3_2,  
       CAST(trmtract AS INT) AS new_trmtract_2, 
       CAST(trptract AS INT) AS new_trptract_2, 
       CAST(owntract AS INT) AS new_owntract_2, 
       act_stat as new_act_stat_2, 
       [crrinter] as new_crrinter_2, 
       [crrhmintra] as new_crrhmintra_2, 
       [crrintra] as new_crrintra_2, 
       [shipinter] as new_shipinter_2, 
       [shipintra] as new_shipintra_2,
	   cast([adddate] as date) as [adddate]
       --CAST(chngdate AS DATE) AS chngdate --could use this as end_date for those with act_stat='I'
INTO #rest
FROM warehouse.dbo.cots_census a
left join (select distinct census_num
from warehouse.dbo.cots_census_changes_all_kf_v2) b
on a.census_num=b.census_num
WHERE b.census_num is NULL AND (owntract != '0'
      OR trmtract != '0'
      OR trptract != '0')
     AND CAST(mlg150 AS FLOAT) > 1
     AND id NOT IN('1', '2', '3', '4');
	 --AND act_stat='A'; -- must have mileage and own tractors and be active

--select count(*)
--from warehouse.dbo.cots_census
--where CAST(mlg150 AS FLOAT) > 1

--select count(*)
--from warehouse.dbo.cots_census
--where mlg150 not in ('0','1') and mlg150 is not null

--select distinct(mlg150)
--from warehouse.dbo.cots_census
--where CAST(mlg150 AS FLOAT) > 1
--order by mlg150

--select distinct(mlg150)
--from warehouse.dbo.cots_census
--where mlg150 not in ('0','1') and mlg150 is not null
--order by mlg150

--select distinct(new_mlg150_2)
--from warehouse.dbo.cots_census_changes_all_kf_v2
--where CAST(new_mlg150_2 AS FLOAT) > 1
--order by new_mlg150_2

--select distinct(new_mlg150_2)
--from warehouse.dbo.cots_census_changes_all_kf_v2
--where new_mlg150_2 not in ('0','1','') --and new_mlg150_2 is not null
--order by new_mlg150_2

-- union 
drop table if exists #all
select   [id]
	    ,[census_num]
		,[start_date2]
		,[end_date]
		,[ntract]
		,[new_fleetsize_2] 
		--,[new_mlg150_2]
		,[new_owntract_2]
		,[new_trmtract_2]
		,[new_trptract_2]
		,[new_act_stat_2]
		,[new_class_2]
		,[new_iccdocket1_2]
		,[new_iccdocket2_2]
		,[new_iccdocket3_2]
		,[new_household_2]
		,[new_crrinter_2]
		,[new_crrhmintra_2]
		,[new_crrintra_2]
		,[new_shipinter_2]
		,[new_shipintra_2]
		,[adddate]
into #all
from #chg
union 
select [id], [census_num]
		,[start_date2]
		,[end_date]
		,[ntract]
		,[new_fleetsize_2]
		--,[new_mlg150_2]
		,[new_owntract_2]
		,[new_trmtract_2]
		,[new_trptract_2]
		,[new_act_stat_2]
		,[new_class_2]
		,[new_iccdocket1_2]
		,[new_iccdocket2_2]
		,[new_iccdocket3_2]
		,[new_household_2]
		,[new_crrinter_2]
		,[new_crrhmintra_2]
		,[new_crrintra_2]
		,[new_shipinter_2]
		,[new_shipintra_2]
		,[adddate]
from #rest


select top(1000)*
from #all
order by census_num, start_date2
----------------------
---> FLEET COUNTS <---
----------------------

---> 1. Total Fleets (FCTC) <---
-- 587	Total Count of Fleets	FCTC (DUMMY=1343)

	DROP TABLE IF EXISTS #data1;
	CREATE TABLE #data1
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data1
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 587 --587	Total Count of Fleets	FCTC
               FROM #all
               WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        -- start_date2 before the month of interest(fleet active before date, the end_date is greater than the month of interest (fleet left after the beginning of the month)

        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #data1

	select *
	from staging.dbo.indx_index_data 
	where index_id=587 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc


---> 2. Private Fleets (FCPF) <---
--903	Total Count of Private Fleets	FCPF (DUMMY=1353)
    drop table if exists #all2
	SELECT *
	INTO #all2
	FROM #all -- this already filters for act_stat='A' and id not in (1,2,3,4) and (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor?? still not sure about this one: cast(mlg150 as float)>0 
	WHERE new_HOUSEHOLD_2 != 'X'
      AND (new_class_2) LIKE '%C%' --class C means 'private', can't move household goods

-- count over months- historic data
	DROP TABLE IF EXISTS #data2;
	CREATE TABLE #data2
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data2
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 903
               FROM #all2
               WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data2

	select *
	from staging.dbo.indx_index_data 
	where index_id=903 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc


--->  3. Intrastate <---
--909 as index_id, 909	Total Count of Intrastate Private Fleets	FCPFIS (DUMMY=1354)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all
	WHERE new_HOUSEHOLD_2 != 'X'
      AND (new_class_2) LIKE '%C%' 
      AND (new_crrhmintra_2 = 'B'
           OR new_crrintra_2 = 'C'
           OR new_shipintra_2 = 'E')-- MC numbers are only 'for hire' so using these variables for intrastate, but also mandating not MC prefix (which is evidence of interstate)
		   and new_iccdocket1_2 != 'MC' and new_iccdocket2_2 != 'MC' and new_iccdocket3_2 != 'MC' --	[FIELD LENGTH 2, FIELD LENGTH 6] (ICCDOCKET1, ICC1), (ICCDOCKET2, ICC2), (ICCDOCKET3, ICC3), Federally-assigned Interstate Commerce Commission entity's identification number. Space allotted for three Docket Number Prefixes (usually MC, MX, or FF) and three ICC Docket Numbers. The terms MC number or MX number have replaced the term ICC number in general usage.	
--  C = Private (Property). An entity whose highway transportation activities are incidental to, and in furtherance of, its primary business activity.

-- count over months- historic data
	DROP TABLE IF EXISTS #data3;
	CREATE TABLE #data3
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data3
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 909
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data3	
	select *
	from staging.dbo.indx_index_data 
	where index_id=909 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

--MX means Mexico-based Carriers for Motor Carrier Authority
--FF means Freight Forwarder Authority
--P means Motor Passenger Carrier Authority
--NNA means Non-North America-Domiciled Motor Carriers
--MC means Motor Carrier Authority?



---> 4. Interstate Private Fleets (FCPFMS) <---
--910 as index_id, 910	Total Count of Interstate Private Fleets	FCPFMS (DUMMY=1355)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
      AND (new_class_2) LIKE '%C%'  --class C means 'private', can't move household goods, and no interstate number
      AND (new_crrinter_2 = 'A'
           OR new_shipinter_2 = 'D' 
		   OR new_iccdocket1_2 = 'MC' OR new_iccdocket2_2 = 'MC' OR new_iccdocket3_2 = 'MC') --interstate. technically MC is just 'for hire', but also checking prefix b/c MC means interstate and possible multiple classes

-- count over months- historic data
	DROP TABLE IF EXISTS #data4;
	CREATE TABLE #data4
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data4
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 910
               FROM #all2
               WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data4	
	select *
	from staging.dbo.indx_index_data 
	where index_id=910 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 5. For Hire Fleets (FCFH) <---
--588 as index_id , 588	Total Count of Fleets Authorized For Hire	FCFH (DUMMY=1344)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
      AND (new_class_2) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (new_class_2) NOT LIKE '%C%' -- if it is for hire, it can't also be private

-- fill in table
	DROP TABLE IF EXISTS #data5;
	CREATE TABLE #data5
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data5
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 588
               FROM #all2
               WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data5	
	select *
	from staging.dbo.indx_index_data 
	where index_id=588 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc


---> 6. Intrastate For Hire Fleets (FCFHIS) <---
--911 as index_id 911	Total Count of Intrastate For Hire Fleets	FCFHIS (DUMMY=1356)
	DROP TABLE IF EXISTS #all2;
	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
		AND (new_class_2) LIKE '%A%' --class A means 'for hire', can't move household goods
		AND (new_class_2) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		AND new_iccdocket1_2 != 'MC' AND new_iccdocket2_2 != 'MC' AND new_iccdocket3_2 != 'MC' -- use MC for-hire inter/intra designation - no MC prefix means intrastate
		AND new_crrinter_2 != 'A' -- also not allowing them to be registered as interstate carrier
		AND new_shipinter_2 != 'D' -- also not allowing them to be registered as interstate shipper
-- fill in table
	DROP TABLE IF EXISTS #data6;
	CREATE TABLE #data6
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data6
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 911
               FROM #all2
               WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data6	
	select *
	from staging.dbo.indx_index_data 
	where index_id=911 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc


-- 7. For Hire Fleets (FCFHMS)
-- 913	Total Count of Interstate For Hire Fleets	FCFHMS (DUMMY=1357)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
      AND (new_class_2) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (new_class_2) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	  AND (new_iccdocket1_2 = 'MC' OR new_iccdocket2_2 = 'MC' OR new_iccdocket3_2 = 'MC') -- use MC for-hire inter/intra designation
-- fill in table
	DROP TABLE IF EXISTS #data7;
	CREATE TABLE #data7
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data7
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 913
               FROM #all2
               WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data7	
	select *
	from staging.dbo.indx_index_data 
	where index_id=913 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 8. New Fleets Authorized For Hire  <---
-- 848	Total Count of New Fleets Authorized For Hire	FCFHN - younger than 18 months (DUMMY=1351)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
      AND (new_class_2) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (new_class_2) NOT LIKE '%C%' -- if it is for hire, it can't also be private
      
-- fill in table
	DROP TABLE IF EXISTS #data8;
	CREATE TABLE #data8
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data8
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 848
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
					 AND DATEDIFF(Month, adddate, @currentDate) < 18; --adddate must be within 18 months of month of interest
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data8	
	select *
	from staging.dbo.indx_index_data 
	where index_id=848 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 9. 849	Total Count of Old Fleets Authorized For Hire	FCFHO <---
-- 849	Total Count of Old Fleets Authorized For Hire	FCFHO  - older than/= to 18 months (DUMMY=1352)
	DROP TABLE IF EXISTS #data9;
	CREATE TABLE #data9
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data9
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 849
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
					 AND DATEDIFF(Month, adddate, @currentDate) >= 18 --adddate must be >= 18 months before month of interest
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data9	
	select *
	from staging.dbo.indx_index_data 
	where index_id=849 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 10. Total Fleets with 1 - 6 Power Unit <---
-- 591	Total Count of Fleets with 1 - 6 Power Units	FCTCO (DUMMY=1345)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('A', 'B', 'C')

-- fill in table
	DROP TABLE IF EXISTS #data10;
	CREATE TABLE #data10
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data10
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 591
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data10	
	select *
	from staging.dbo.indx_index_data 
	where index_id=591 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 11. Total Count of Fleets with 7 - 11 Power Units --
-- 592	Total Count of Fleets with 7 to 11 Power Units	FCTCS (DUMMY=1346)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('D', 'E')
-- fill in table
	DROP TABLE IF EXISTS #data11;
	CREATE TABLE #data11
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data11
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 592
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data11	
	select *
	from staging.dbo.indx_index_data 
	where index_id=592 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 12. Total Count of Fleets with 12 - 19 Power Units
-- 751	Total Count of Fleets With 12 - 19 Power Units	FCTCT (DUMMY=1350)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('F', 'G', 'H')
-- fill in table
	DROP TABLE IF EXISTS #data12;
	CREATE TABLE #data12
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data12
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 751
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data12
	select *
	from staging.dbo.indx_index_data 
	where index_id=751 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 13. Total Count of Fleets with 20 - 100 Power Units
-- 593	Total Count of Fleets with 20 to 100 Power Units	FCTCM (DUMMY=1347)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('I', 'J', 'K', 'L', 'M', 'N', 'O', 'P')
-- fill in table
	DROP TABLE IF EXISTS #data13;
	CREATE TABLE #data13
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data13
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 593
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data13
	select *
	from staging.dbo.indx_index_data 
	where index_id=593 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 14. Total Count of Fleets with 101 - 999 Power Units
-- 594	Total Count of Fleets with 101 to 999 Power Units	FCTCL (DUMMY=1348)
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('Q', 'R', 'S', 'T', 'U')
-- fill in table
	DROP TABLE IF EXISTS #data14;
	CREATE TABLE #data14
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data14
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 594
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data14
	select *
	from staging.dbo.indx_index_data 
	where index_id=594 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 15. Total Count of Fleets with 1000+ Power Units
-- 595	Total Count of Fleets with 1000+ Power Units	FCTCE (DUMMY=1349)
   DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('V', 'W', 'X', 'Y', 'Z')
-- fill in table
	DROP TABLE IF EXISTS #data15;
	CREATE TABLE #data15
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

        -- count active fleets
        INSERT INTO #data15
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      COUNT(DISTINCT(census_num)) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 595
               FROM #all2
                WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

	select *
	from #data15
	select *
	from staging.dbo.indx_index_data 
	where index_id=595 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc


---> TRACTOR COUNTS <---
-- want the average count per census_num

---> 1. Total Fleets (FCTC) <---
-- Total Count of Tractors	

	DROP TABLE IF EXISTS #d1;
	CREATE TABLE #d1
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d1
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1366
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
--2318752
	select *
	from #d1

	select *
	from staging.dbo.indx_index_data 
	where index_id=1366 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc


---> 2. Private Fleets (FCPF) <---
--1376	Total Count of Private Tractors	TCPF

    drop table if exists #all2
	SELECT *
	INTO #all2
	FROM #all -- this already filters for act_stat='A' and id not in (1,2,3,4) and (cast(owntract as int) > 0 or cast(trmtract as int) > 0 or cast(trptract as int) > 0 )-- must have tractor?? still not sure about this one: cast(mlg150 as float)>0 
	WHERE new_HOUSEHOLD_2 != 'X'
      AND (new_class_2) LIKE '%C%' --class C means 'private', can't move household goods

	DROP TABLE IF EXISTS #d2;
	CREATE TABLE #d2
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d2
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1376
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d2

	select *
	from staging.dbo.indx_index_data 
	where index_id=1376 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

--->  3. Intrastate <---
--1377	Total Count of Intrastate Private Tractors	TCPFIS
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all
	WHERE new_HOUSEHOLD_2 != 'X'
      AND (new_class_2) LIKE '%C%' 
      AND (new_crrhmintra_2 = 'B'
           OR new_crrintra_2 = 'C'
           OR new_shipintra_2 = 'E')-- MC numbers are only 'for hire' so using these variables for intrastate, but also mandating not MC prefix (which is evidence of interstate)
		   and new_iccdocket1_2 != 'MC' and new_iccdocket2_2 != 'MC' and new_iccdocket3_2 != 'MC' --	[FIELD LENGTH 2, FIELD LENGTH 6] (ICCDOCKET1, ICC1), (ICCDOCKET2, ICC2), (ICCDOCKET3, ICC3), Federally-assigned Interstate Commerce Commission entity's identification number. Space allotted for three Docket Number Prefixes (usually MC, MX, or FF) and three ICC Docket Numbers. The terms MC number or MX number have replaced the term ICC number in general usage.	
--  C = Private (Property). An entity whose highway transportation activities are incidental to, and in furtherance of, its primary business activity.

	DROP TABLE IF EXISTS #d3;
	CREATE TABLE #d3
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d3
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1377
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d3

	select *
	from staging.dbo.indx_index_data 
	where index_id=1377 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 4. Interstate Private Fleets (FCPFMS) <---
--1378	Total Count of Interstate Private Tractors	TCPFMS
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
      AND (new_class_2) LIKE '%C%'  --class C means 'private', can't move household goods, and no interstate number
      AND (new_crrinter_2 = 'A'
           OR new_shipinter_2 = 'D' 
		   OR new_iccdocket1_2 = 'MC' OR new_iccdocket2_2 = 'MC' OR new_iccdocket3_2 = 'MC') --interstate. technically MC is just 'for hire', but also checking prefix b/c MC means interstate and possible multiple classes


	DROP TABLE IF EXISTS #d4;
	CREATE TABLE #d4
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d4
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1378
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d4

	select *
	from staging.dbo.indx_index_data 
	where index_id=1378 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 5. For Hire Fleets (FCFH) <---
--1367	Total Count of Tractors Authorized For Hire	TCFH
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
      AND (new_class_2) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (new_class_2) NOT LIKE '%C%' -- if it is for hire, it can't also be private

	DROP TABLE IF EXISTS #d5;
	CREATE TABLE #d5
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d5
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1367
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d5

	select *
	from staging.dbo.indx_index_data 
	where index_id=1367 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 6. Intrastate For Hire Fleets (FCFHIS) <---
--1379	Total Count of Intrastate For Hire Tractors	TCFHIS
	DROP TABLE IF EXISTS #all2;
	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
		AND (new_class_2) LIKE '%A%' --class A means 'for hire', can't move household goods
		AND (new_class_2) NOT LIKE '%C%' -- if it is for hire, it can't also be private
		AND new_iccdocket1_2 != 'MC' AND new_iccdocket2_2 != 'MC' AND new_iccdocket3_2 != 'MC' -- use MC for-hire inter/intra designation - no MC prefix means intrastate
		AND new_crrinter_2 != 'A' -- also not allowing them to be registered as interstate carrier
		AND new_shipinter_2 != 'D' -- also not allowing them to be registered as interstate shipper


	DROP TABLE IF EXISTS #d6;
	CREATE TABLE #d6
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d6
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1379
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d6

	select *
	from staging.dbo.indx_index_data 
	where index_id=1379 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 7. Interstate For Hire Fleets (FCFHMS) <---
-- 1380	Total Count of Interstate For Hire Tractors	TCFHMS
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
      AND (new_class_2) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (new_class_2) NOT LIKE '%C%' -- if it is for hire, it can't also be private
	  AND (new_iccdocket1_2 = 'MC' OR new_iccdocket2_2 = 'MC' OR new_iccdocket3_2 = 'MC') -- use MC for-hire inter/intra designation


	DROP TABLE IF EXISTS #d7;
	CREATE TABLE #d7
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d7
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1380
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d7

	select *
	from staging.dbo.indx_index_data 
	where index_id=1380 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 8. New Fleets Authorized For Hire  <---
-- 1374	Total Count of New Tractors Authorized For Hire	TCFHN - younger than 18 months
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_household_2 != 'X'
      AND (new_class_2) LIKE '%A%' --class A means 'for hire', can't move household goods
	  AND (new_class_2) NOT LIKE '%C%' -- if it is for hire, it can't also be private

	DROP TABLE IF EXISTS #d8;
	CREATE TABLE #d8
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
					 AND DATEDIFF(Month, adddate, @currentDate) < 18 --adddate must be within 18 months of month of interest
	group by census_num

        -- count tractors
        INSERT INTO #d8
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1374
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d8

	select *
	from staging.dbo.indx_index_data 
	where index_id=1374 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

	-- how many are active at the start of their add date- hopefully a lot - yes.
	select new_act_stat_2, count(id) as cnt
	from warehouse.dbo.cots_census_changes_all_kf_v2
	where adddate=[start_date]
	group by new_act_stat_2

	--select top(100) [census_num], [start_date2], [adddate],[new_act_stat_2]
	--from warehouse

---> 9. Total Count of Old Fleets Authorized For Hire	FCFHO <---
-- 1375	Total Count of Old Tractors Authorized For Hire	TCFHO  - older than/= to 18 months

	DROP TABLE IF EXISTS #d9;
	CREATE TABLE #d9
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
					 AND DATEDIFF(Month, adddate, @currentDate) >= 18 --adddate must be >= 18 months before month of interest - technically this should be the min start_date where active
	group by census_num

        -- count tractors
        INSERT INTO #d9
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1375
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d9

	select *
	from staging.dbo.indx_index_data 
	where index_id=1375 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

---> 10. Total Fleets with 1 - 6 Power Unit <---
-- 1368	Total Count of Tractors with 1 - 6 Power Units
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('A', 'B', 'C')

	DROP TABLE IF EXISTS #d10;
	CREATE TABLE #d10
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d10
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1368
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
--509707
	select *
	from #d10

	select *
	from staging.dbo.indx_index_data 
	where index_id=1368 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 11. Total Count of Fleets with 6 - 11 Power Units --
-- 1369	Total Count of Tractors with 7 to 11 Power Units	TCTCS
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('D', 'E')

	DROP TABLE IF EXISTS #d11;
	CREATE TABLE #d11
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d11
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1369
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d11

	select *
	from staging.dbo.indx_index_data 
	where index_id=1369 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc


-- 12. Total Count of Fleets with 12 - 19 Power Units
-- 1373	Total Count of Tractors With 12 - 19 Power Units	TCTCT
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('F', 'G', 'H')

	DROP TABLE IF EXISTS #d12;
	CREATE TABLE #d12
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d12
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1373
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d12

	select *
	from staging.dbo.indx_index_data 
	where index_id=1373 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 13. Total Count of Fleets with 20 - 100 Power Units
-- 1370	Total Count of Tractors with 20 to 100 Power Units 	TCTCM
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('I', 'J', 'K', 'L', 'M', 'N', 'O', 'P')

	DROP TABLE IF EXISTS #d13;
	CREATE TABLE #d13
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d13
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1370
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d13

	select *
	from staging.dbo.indx_index_data 
	where index_id=1370 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 14. Total Count of Fleets with 101 - 999 Power Units
-- 1371	Total Count of Tractors with 101 to 999 Power Units 	TCTCL
    DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('Q', 'R', 'S', 'T', 'U')

	DROP TABLE IF EXISTS #d14;
	CREATE TABLE #d14
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d14
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1371
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d14

	select *
	from staging.dbo.indx_index_data 
	where index_id=1371 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc

-- 15. Total Count of Fleets with 1000+ Power Units
-- 1372	Total Count of Tractors with 1000+ Power Units	TCTCE
   DROP TABLE IF EXISTS #all2;
 	SELECT *
	INTO #all2
	FROM #all 
	WHERE new_fleetsize_2 IN('V', 'W', 'X', 'Y', 'Z')

	DROP TABLE IF EXISTS #d15;
	CREATE TABLE #d15
	(data_timestamp      DATE, 
	 data_value          INT, 
	 granularity_item_id INT, 
	 index_id            INT
	);
	DECLARE @currentDate DATETIME;
	SELECT @currentDate = '2008-01-09';
	WHILE @currentDate < '2018-08-01'
    BEGIN

	-- avg tractor per census_num
	drop table if exists #a
	select census_num,
		   avg(ntract) as avgntract
    into #a
	from #all2
    WHERE(start_date2 <= @currentDate
                     AND end_date > DATEADD(month, -1, @currentDate))
	group by census_num

        -- count tractors
        INSERT INTO #d15
               SELECT CAST(@currentDate AS DATE) AS data_timestamp, 
                      SUM(avgntract) AS data_value, 
                      granularity_item_id = 1, 
                      index_id = 1372
               FROM #a
 
        SELECT @currentDate = DATEADD(month, 1, @currentDate);
    END;

---- checking it
	select *
	from #d15

	select *
	from staging.dbo.indx_index_data 
	where index_id=1372 and data_timestamp >= '2018-05-09'
	order by data_timestamp asc


-- combine
DROP TABLE IF EXISTS #hist;
CREATE TABLE #hist
(data_timestamp      DATE, 
 data_value          INT, 
 granularity_item_id INT, 
 index_id            INT
);
INSERT INTO #hist
       SELECT *
       FROM #d1
       UNION
       SELECT *
       FROM #d2
       UNION
       SELECT *
       FROM #d3
       UNION
       SELECT *
       FROM #d4
       UNION
       SELECT *
       FROM #d5
       UNION
       SELECT *
       FROM #d6
       UNION
       SELECT *
       FROM #d7
       UNION
       SELECT *
       FROM #d8
       UNION
       SELECT *
       FROM #d9
       UNION
       SELECT *
       FROM #d10
       UNION
       SELECT *
       FROM #d11
       UNION
       SELECT *
       FROM #d12
       UNION
       SELECT *
       FROM #d13
       UNION
       SELECT *
       FROM #d14
       UNION
       SELECT *
       FROM #d15;

select index_id, count(index_id) as cnt
from #hist
group by index_id



-- to replace in indx_index_data
	--INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)
	SELECT *
	FROM #hist
	--where data_timestamp < '2018-08-01' 

CREATE TABLE warehouse.dbo.cots_census_tractor_count_history_kf
(data_timestamp      DATE, 
 data_value          INT, 
 granularity_item_id INT, 
 index_id            INT,
 ticker				 VARCHAR(150),
 index_name			 VARCHAR(150)
);


INSERT INTO warehouse.dbo.cots_census_tractor_count_history_kf (data_timestamp,
 data_value,
 granularity_item_id,
 index_id,
 ticker,
 index_name)
 select a.*, b.ticker, b.index_name
 from 
 (select data_timestamp,
		 data_value,
		 granularity_item_id,
		 index_id
 from #hist 
 union 
 select data_timestamp,
		 data_value,
		 granularity_item_id,
		 index_id
 from staging.dbo.indx_index_data
 where index_id in (1374,
					1377,
					1366,
					1380,
					1369,
					1375,
					1372,
					1378,
					1376,
					1367,
					1373,
					1370,
					1371,
					1379,
					1368)
 ) a
 inner join 
 staging.dbo.indx_index_definition b
 on a.index_id=b.id
 order by index_id, data_timestamp

 -- updating descriptions:
update staging.dbo.indx_index_definition
set index_name='Total Count of Tractors from Fleets with 7 - 11 Power Units' where id=1369
update staging.dbo.indx_index_definition
set index_name='Total Count of Tractors from Fleets with 20 - 100 Power Units' where id=1370
update staging.dbo.indx_index_definition
set index_name='Total Count of Tractors from Fleets with 101 - 999 Power Units' where id=1371
update staging.dbo.indx_index_definition
set [description]='Monthly Total Count of Tractors from Fleets with 1 to 6 Power Units Reported to FMCSA. New methodology used starting Aug 2018.' where id=1368
update staging.dbo.indx_index_definition
set [description]='Monthly Total Count of Tractors from Fleets With 12 to 19 Power Units Reported to FMCSA. New methodology used starting Aug 2018.' where id=1373

--update staging.dbo.indx_index_definition
--set  [description]=concat(trim([description]), ' Subject to revision.')
select * from  staging.dbo.indx_index_definition
where id in (1374,
					1377,
					1366,
					1380,
					1369,
					1375,
					1372,
					1378,
					1376,
					1367,
					1373,
					1370,
					1371,
					1379,
					1368) 

select index_name, [description]=concat(trim([description]), ' Subject to revision.')
from staging.dbo.indx_index_definition
where id in (1374,
					1377,
					1366,
					1380,
					1369,
					1375,
					1372,
					1378,
					1376,
					1367,
					1373,
					1370,
					1371,
					1379,
					1368) 

  select *
from staging.dbo.indx_index_definition
where id in  (1374,
					1377,
					1366,
					1380,
					1369,
					1375,
					1372,
					1378,
					1376,
					1367,
					1373,
					1370,
					1371,
					1379,
					1368) 


select *
from staging.dbo.indx_index_definition
where id in (593,
					848,
					587,
					591,
					903,
					911,
					751,
					588,
					594,
					849,
					909,
					595,
					910,
					913,
					592) 

 -- adding history for tractor counts:
 --insert into staging.dbo.indx_index_data ( data_timestamp, data_value ,granularity_item_id, index_id )
 select 
 data_timestamp,      
 data_value ,         
 granularity_item_id,  
 index_id
 from warehouse.dbo.cots_census_tractor_count_history_kf
 where index_id in (1374,
					1377,
					1366,
					1380,
					1369,
					1375,
					1372,
					1378,
					1376,
					1367,
					1373,
					1370,
					1371,
					1379,
					1368) and data_timestamp <= '2018-08-01'
order by index_id, data_timestamp

select * from staging.dbo.indx_index_data 
 where index_id in (1374,
					1377,
					1366,
					1380,
					1369,
					1375,
					1372,
					1378,
					1376,
					1367,
					1373,
					1370,
					1371,
					1379,
					1368) --and data_timestamp <= '2018-08-01'
order by index_id, data_timestamp


-- adding the revised fleet count history in:
--insert into staging.dbo.indx_index_data ( data_timestamp,      data_value ,granularity_item_id,  index_id )
select 
 data_timestamp,      
 data_value ,         
 1 as granularity_item_id,  
 index_id
 from warehouse.dbo.cots_census_tractor_count_history_kf
 where index_id in (593,
					848,
					587,
					591,
					903,
					911,
					751,
					588,
					594,
					849,
					909,
					595,
					910,
					913,
					592) and data_timestamp <= '2018-08-01' and  granularity_item_id=2
order by index_id, data_timestamp 

insert into staging.dbo.indx_index_data ( data_timestamp,      data_value ,granularity_item_id,  index_id )
select 
 data_timestamp,      
 data_value ,         
 1 as granularity_item_id,  
 index_id
 from warehouse.dbo.cots_census_tractor_count_history_kf
 where index_id in (593,
					848,
					587,
					591,
					903,
					911,
					751,
					588,
					594,
					849,
					909,
					595,
					910,
					913,
					592) and data_timestamp > '2018-08-01' and data_timestamp < '2019-08-01' and  granularity_item_id=3
order by index_id, data_timestamp 

--delete from staging.dbo.indx_index_data
select * from staging.dbo.indx_index_data
 where index_id in (593,
					848,
					587,
					591,
					903,
					911,
					751,
					588,
					594,
					849,
					909,
					595,
					910,
					913,
					592) and data_timestamp > '2018-08-01'
order by index_id, data_timestamp 

 -- fleets
 -- combine
DROP TABLE IF EXISTS #histf;
CREATE TABLE #histf
(data_timestamp      DATE, 
 data_value          INT, 
 granularity_item_id INT, 
 index_id            INT
);
INSERT INTO #histf
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

select index_id, count(index_id) as cnt
from #histf
group by index_id

-- to replace in indx_index_data
	--INSERT INTO staging.dbo.indx_index_data(data_timestamp, data_value, granularity_item_id, index_id)
	SELECT *
	FROM #histf
	--where data_timestamp < '2018-08-01' 


	select distinct(index_id)
	from #histf

INSERT INTO warehouse.dbo.cots_census_tractor_count_history_kf (data_timestamp,
 data_value,
 granularity_item_id,
 index_id,
 ticker,
 index_name)
 select a.*, b.ticker, b.index_name
 from 
 (select data_timestamp,
		 data_value,
		 2 as granularity_item_id, --2 means new
		 index_id
 from #histf 
 union 
 select data_timestamp,
		 data_value,
		 3 as granularity_item_id, --3 means prod
		 index_id
 from staging.dbo.indx_index_data
 where index_id in (593,
					848,
					587,
					591,
					903,
					911,
					751,
					588,
					594,
					849,
					909,
					595,
					910,
					913,
					592)
 ) a
 inner join 
 staging.dbo.indx_index_definition b
 on a.index_id=b.id
 order by index_id, data_timestamp







 -- exploring mid-2011 drop
 drop table if exists #t1219
 select *
 into #t1219
 from warehouse.dbo.cots_census_changes_all_kf_v2
 where new_fleetsize_2  IN ('F', 'G', 'H')

 select [start_date], count(id) as cnt
 from warehouse.dbo.cots_census_changes_all_kf_v2
 where new_act_stat_2='I'
 and new_fleetsize_2  IN ('F', 'G', 'H')
 group by [start_date]
 order by cnt

 -- get the maximum end_date where new_act_stat_2='A' per census_num
 drop table if exists #end
 select census_num, max([end_date]) as maxdt
 into #end
 from #all--warehouse.dbo.cots_census_changes_all_kf_v2
 where new_act_stat_2='A'  and new_fleetsize_2  IN ('F', 'G', 'H')
 group by census_num

  select maxdt, count(maxdt) as cnt
 from #end
 group by maxdt
 order by cnt desc

 drop table if exists #start
 select census_num, min([start_date2]) as mindt
 into #start
 from #all--warehouse.dbo.cots_census_changes_all_kf_v2
 where new_act_stat_2='A'  
 group by census_num

 select mindt, count(mindt) as cnt
 from #start
 group by mindt
 order by cnt desc

 select cast(updatedByDT as date), count(id) as cnt
 from warehouse.dbo.cots_census
 group by cast(updatedByDT as date)
 order by cnt desc

 -- most frequent createdates
  select try_cast(createdate as date), count(id) as cnt
 from warehouse.dbo.cots_census
 group by try_cast(createdate as date)
 order by cnt desc


 select cast(adddate as date), count(id) as cnt
 from warehouse.dbo.cots_census
 group by cast(adddate as date)
 order by cnt desc

 --most frequent updatebydt
 select cast(updatedByDT as date), count(id) as cnt
 from warehouse.dbo.cots_census_changes_full
 group by cast(updatedByDT as date)
 order by cnt desc

 select cast(end_date as date), count(id) as cnt
 from warehouse.dbo.cots_census_changes_all_kf_v2
 where new_act_stat_2='A'
 group by cast(end_date as date)
 order by cnt desc

 select top (1000)*
 from #all 
 where end_date='1900-01-01'
 select top (1000) census_num, adddate, createdate, act_stat, chngdate, validasof
 from warehouse.dbo.cots_census
 where try_cast(createdate as date)='1900-01-01'







