USE [Staging]
GO
/****** Object:  StoredProcedure [dbo].[census_to_census_ref]    Script Date: 8/13/2019 9:50:48 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kate Fisher (based on 2019-06-27 stored 'census_to_census_ref' procedure by Alex Quevedo, but with edits to stock_ticker, but not many edits to logic on assigning parent company. 
-- Great task for someone: checking the logic on assigning DOT_Numbers to a parent company against a website/registry. I checked against some for missing DOT numbers and added below.
-- Create date: 13Aug2019 
-- Description:	Create list of parent, child relations into Warehouse.dbo.FMCSA_census_parent_child 
--				To replace the census_to_census_ref 
-- =============================================
ALTER PROCEDURE [dbo].[create_FMCSA_census_parent_child]

	@datetouse DATE = '' -- EC: provide datetouse as a parameter, that way if we ever need to run the proc with a different date then we can without altering code


AS

BEGIN
--look up table for this!
	-- get any new DOT_Numbers that would be assigned into a parent company 

--declare @datetouse DATE = '' --uncomment for testing
	SET @datetouse = (SELECT CASE
								WHEN @datetouse = '1900-01-01' THEN MAX(data_timestamp) 
								ELSE @datetouse
							 END as date_to_use
					  FROM Staging.dbo.indx_index_data
					  WHERE index_id = 587)  -- EC: If no date is provided default to he max data_timestamp from index data for index_id 587, else use provided date
--select @datetouse

	DROP TABLE IF EXISTS #all;
	SELECT cast(createdate as date) as asofdate
		   ,DOT_NUMBER 
		   ,[name]
		   ,[EMAILADDRESS]
		   ,[OWNTRACT]
		   ,[TRMTRACT]
		   ,[TRPTRACT]
		   ,cast([OWNTRACT] as numeric)+cast([TRMTRACT] as numeric)+cast([TRPTRACT] as numeric) as tract_totn
		   --,b.maxdt
	INTO #all
	FROM Warehouse.dbo.FMCSA_Census 
	WHERE createdate>=@datetouse

select count( distinct(dot_number))
from #all

	DROP TABLE IF EXISTS #Temp;
	CREATE TABLE #temp
	(Parent_Company VARCHAR(255), 
	 Child_Company  VARCHAR(255), 
	 Stock_Ticker   VARCHAR(10), 
	 DOT_Number     VARCHAR(50), 
	 as_of_date     DATETIME,
	 EMAILADDRESS   VARCHAR(255), 
	 tract_tot		int
	);

		-- 1. FedEx Corp.
	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'FDX' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date,
            CASE
                WHEN [name] = 'Desoto Trucking & Backhoe LLC'
                THEN 'FedEx Corp.'
                WHEN [name] = 'Federal Express Canada Corporation'
                THEN 'FedEx Corp.'
                WHEN [name] = 'Federal Express Corporation'
                THEN 'FedEx Corp.'
                WHEN [name] = 'Federal Express Freight Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Auto Transport Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Custom Critical AutoTrans Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Custom Critical Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Forward Depots Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Freight Canada Corp'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Freight Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Ground Package System Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Ground Package System LTD'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Office and Print Services Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Supply Chain Distribution System Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Supply Chain Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Supply Chain Logistics & Electronics Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Supply Chain Transportation Management LLC'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Trade Networks Transport & Brokerage Inc'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Transportation Company LLC'
                THEN 'FedEx Corp.'
                WHEN [name] = 'FedEx Truckload Brokerage LLC'
                THEN 'FedEx Corp.'
                WHEN [name] = 'Genco Infrastructure Solutions'
                THEN 'FedEx Corp.'
                WHEN [name] = 'James M McNally'
                THEN 'FedEx Corp.'
                WHEN [name] = 'Lorenzo Sanchez Nino'
                THEN 'FedEx Corp.'
                WHEN [name] = 'MS Federal Express Inc'
                THEN 'FedEx Corp.'
                ELSE NULL
            END AS Parent_Company,
						EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE '%Federal Express%'
            OR [NAME] LIKE '%FedEx%'
            OR [NAME] LIKE '%World Tariff%'
            OR [NAME] LIKE '%FCJI%'
            OR [NAME] LIKE '%Federal Europe%'
            OR EMAILADDRESS LIKE '%@fedex%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

		-- 2. XPO Logistics

	INSERT INTO #temp
	(DOT_Number, 
	Child_Company, 
	Stock_Ticker, 
	as_of_date, 
	Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
	SELECT DISTINCT 
			DOT_NUMBER, 
			[NAME] AS Child_Company, 
			'XPO' AS Stock_Ticker, 
			MAX(asofdate) AS as_of_date,
			CASE
				WHEN [name] = 'Con-Way Multimodal Inc'
				THEN 'XPO Logistics'
				WHEN [name] = 'D Hill Transportation LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'Jacobson Transportation Company Inc'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Dedicated LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Intermodal Solutions INC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Last MIle Inc'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Canada Inc'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Cartage LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Drayage LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Express LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Freight Canada Inc'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Freight Inc'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Managed Transportation LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Manufacturing LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics NLM LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Port Services LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Supply Chain Inc'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics Worldwide Government Services LLC'
				THEN 'XPO Logistics'
				WHEN [name] = 'XPO Logistics WorldWide Inc'
				THEN 'XPO Logistics'
				ELSE NULL
			END AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE([NAME] LIKE 'XPO'
			OR [NAME] LIKE 'XPO Logistics%'
			OR [NAME] LIKE '%XPO CNQ%'
			OR [NAME] LIKE '%XPO Intermodal%'
			OR [NAME] LIKE '%XPO Last Mile%'
			OR EMAILADDRESS LIKE '%@xpo.com')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]


	--	3. JB Hunt stuff 
	INSERT INTO #temp
	(DOT_Number, 
		Child_Company, 
		Stock_Ticker,
		as_of_date, 
		Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'JBHT' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date, 
            'J.B. Hunt Transport Services' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE '%J. B. Hunt%'
            OR [NAME] LIKE '%J B Hunt%'
            OR [NAME] LIKE 'JBHT'
            OR [NAME] LIKE '%Hunt Mexicana%'
            OR [NAME] LIKE '%Special Logistics%'
            OR EMAILADDRESS LIKE '@jbhunt%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 4. Knight-Swift Transportation Holdings

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'KNX' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date,
            CASE
                WHEN [name] = 'Abilene Motor Express Inc'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Barr-Nunn Logistics Inc'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Interstate Equipment Leasing'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Knight Logistics LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Knight Port Services LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Knight Refrigerated LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Knight Transportation Inc'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Knight Transportation Services Inc'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Kold Trans LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'MS Carriers LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Swift Intermodal LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Swift Logistics LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Swift Transportation Canada Inc'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Swift Transportation CO of Arizona LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Swift Transportation Services LLC'
                THEN 'Knight-Swift Transportation Holdings'
                WHEN [name] = 'Trans-Mex Inc SA de CV'
                THEN 'Knight-Swift Transportation Holdings'
                ELSE NULL
            END AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE 'Swift Transportation Co of Arizona%'
            OR [NAME] LIKE 'Swift Transportation Services%'
            OR [NAME] LIKE 'Interstate Equipment Leasing%'
            OR [NAME] LIKE 'MS Carrier LLC%'
            OR [NAME] LIKE 'Swift Intermodal%'
            OR [NAME] LIKE 'Swift Logistics LLC%'
            OR [NAME] LIKE 'Knight Refrigerated LLC%'
            OR [NAME] LIKE 'Knight Logistics LLC%'
            OR [NAME] LIKE 'Knight Transportation Services Inc%'
            OR [NAME] LIKE 'Kold Trans LLC%'
            OR [NAME] LIKE 'Barr-Nunn%'
            OR [NAME] LIKE 'Knight Port Services%'
            OR [NAME] LIKE 'Knight Transportation Inc%'
            OR [NAME] LIKE 'Knight Transportation Services%'
            OR [NAME] LIKE 'Abilene Motor Express%'
            OR EMAILADDRESS LIKE '%@swifttrans.com%'
            OR EMAILADDRESS LIKE '%@knighttrans.com%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]



	-- 5. YRC Worldwide Inc. --KF: this should be YRCW and not YRWC. Updated

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'YRCW' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date, --KF: updating stock_ticker from YRWC to YRCW
            CASE
                WHEN [name] = 'HNRY Logistics Inc'
                THEN 'YRC Worldwide Inc'
                WHEN [name] = 'New Penn Motor Express LLC'
                THEN 'YRC Worldwide Inc'
                WHEN [name] = 'Reimer Express Lines Company'
                THEN 'YRC Worldwide Inc'
                WHEN [name] = 'Reimer Express Lines LTD'
                THEN 'YRC Worldwide Inc'
                WHEN [name] = 'USF Holland LLC'
                THEN 'YRC Worldwide Inc'
                WHEN [name] = 'USF Reddaway Inc'
                THEN 'YRC Worldwide Inc'
                WHEN [name] = 'YRC Inc'
                THEN 'YRC Worldwide Inc'
                ELSE NULL
            END AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE '110581 Ontario%'
            OR [NAME] LIKE 'Express Lane Service%'
            OR [NAME] LIKE 'New Penn Motor Express%'
            OR [NAME] LIKE 'Roadway LLC%'
            OR [NAME] LIKE 'USF Holland LLC%'
            OR [NAME] LIKE 'YRC Association Solutions%'
            OR [NAME] LIKE 'YRC Mortgages%'
            OR [NAME] LIKE 'YRC Regional Transportation%'
            OR [NAME] LIKE 'YRC Enterprise Services%'
            OR [NAME] LIKE 'Roadway Next Day Co%'
            OR [NAME] LIKE 'YRC Inc%'
            OR [NAME] LIKE 'Reimer Holding%'
            OR [NAME] LIKE 'Reimer Express Lines%'
            OR [NAME] LIKE 'YRC Transportation%'
            OR [NAME] LIKE 'Roadway Express SA de CV%'
            OR [NAME] LIKE 'Roadway Express International%'
            OR [NAME] LIKE 'Transcontinental Lease%'
            OR [NAME] LIKE 'HNRY Logistics%'
            OR [NAME] LIKE 'YRC Services%'
            OR [NAME] LIKE 'USF Holland International Sales%'
            OR [NAME] LIKE 'USF Bestway%'
            OR [NAME] LIKE 'USF Dugan%'
            OR [NAME] LIKE 'USF Glen Moore%'
            OR [NAME] LIKE 'USF Reddaway%'
            OR [NAME] LIKE 'USF Redstar%'
            OR [NAME] LIKE 'YRC Logistics Services%'
            OR [NAME] LIKE 'YRC Logistics%'
            OR EMAILADDRESS LIKE '%@yrcfreight.com%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 6. Hub Group Inc.

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'HUBG' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date, 
            'Hub Group Inc' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE 'Hub City Terminals Inc'
            OR [NAME] LIKE 'Hub Group%'
            OR [NAME] LIKE 'Hub Chicago Holdings%'
            OR [NAME] LIKE 'Hub Freight Services%'
            OR [NAME] LIKE 'HGNA Group de Mexico%'
            OR [NAME] LIKE 'HGNA Services%'
            OR [NAME] LIKE 'Mode Transportation%'
            OR [NAME] LIKE 'Mode Freight Services%'
            OR EMAILADDRESS LIKE '%@hubgroup.com%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 7. Landstar System Inc

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'LSTR' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date, 
            'Landstar System Inc.' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE 'Landstar %'
            AND [name] NOT LIKE 'Landstar Riverside%'
            AND [name] NOT LIKE 'Landstar Kids%'
            AND [name] NOT LIKE 'Landstar Garden%'
            AND [name] NOT LIKE 'Landstar Poole%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]


	-- 8. Old Dominion Freight Line Inc

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'ODFL' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date, 
            'Old Dominion Freight Line' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE 'Old Dominion%'
            OR EMAILADDRESS LIKE '%@olddominion.com%'
            OR EMAILADDRESS LIKE '%@odlf.com%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 9.Werner Enterprises Inc

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'WERN' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date, 
            'Werner Enterprises' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE 'Werner Company%'
            OR [NAME] LIKE 'Fleet Truck Sales%'
            OR [NAME] LIKE 'Werner Air%'
            OR [NAME] LIKE 'Werner Global%'
            OR [NAME] LIKE 'Werner Transport%'
            OR [NAME] LIKE 'Werner Enterprises%'
            OR [NAME] LIKE 'American Institute of Trucking Inc%'
            OR [NAME] LIKE 'Career Path Training Corp%'
            OR EMAILADDRESS LIKE '%@werner.com%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 10. Roadrunner Transportation Systems Inc
	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'RRTS' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date,
            CASE
                WHEN [name] = 'A&A Logistics LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Active Global Solutions LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Active PTM LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Ascent Global Logistics LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Big Rock Transportation LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Capital Transportation Logistics LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Central Cal Transportation LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'CTW Transport LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'D&E Transport LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Expedited Freight Systems LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Great Northern Transportation Services LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'ISI Logistics LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'ISI Logistics South LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Marisol International LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Midwest Transit Inc'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Morgan Southern Inc'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Prime Distribution Services Inc'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Rich Transport LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Roadrunner Freight Carriers LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Roadrunner Intermodal Services LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Roadrunner Temperature Controlled LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Roadrunner Temperature ControlledLLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Roadrunner Transportation Services Inc'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Roadrunner Truckload 2 LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'RRTC Holdings Inc'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Sargent Trucking LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Sortino Transportation LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Stagecoach Cartage and Distribution LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'Wando Trucking LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                WHEN [name] = 'World Transport Services LLC'
                THEN 'Roadrunner Transportation Systems Inc'
                ELSE NULL
            END AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE 'A&A	Express LLC%'
            OR [NAME] LIKE 'A&A Logistics LLC%'
            OR [NAME] LIKE 'Great Northern Transportation Services%'
            OR [NAME] LIKE 'Active Global%'
            OR [NAME] LIKE 'Active PTM%'
            OR [NAME] LIKE 'Sargent Trucking LLC%'
            OR [NAME] LIKE 'Sortino Transportation%'
            OR [NAME] LIKE 'Ascent Global%'
            OR [NAME] LIKE 'ISI Logistics LLC%'
            OR [NAME] LIKE 'Big Rock Transportation%'
            OR [NAME] LIKE 'Capital Transportation Logistics%'
            OR [NAME] LIKE 'Central Cal Transportation LLC%'
            OR [NAME] LIKE 'Marisol International%'
            OR [NAME] LIKE 'CTW Transport LLC%'
            OR [NAME] LIKE 'D&E Transport LLC%'
            OR [NAME] LIKE 'Expedited Freight Systems%'
            OR [NAME] LIKE 'Stagecoach Cartage and Distribution%'
            OR [NAME] LIKE 'Midwest Transit Inc%'
            OR [NAME] LIKE 'Morgan Southern%'
            OR [NAME] LIKE 'Prime Distribution Services%'
            OR [NAME] LIKE 'Rich Transport LLC%'
            OR [NAME] LIKE 'Roadrunner Freight Carriers%'
            OR [NAME] LIKE 'Roadrunner Intermodal Services%'
            OR [NAME] LIKE 'Roadrunner Temperature Controlled%'
            OR [NAME] LIKE 'Roadrunner Transportation Services Inc%'
            OR [NAME] LIKE 'Roadrunner Truckload 2%'
            OR [NAME] LIKE 'RRTC Holdings%'
            OR [NAME] LIKE 'Wando Trucking%'
            OR [NAME] LIKE 'World Transport Services%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 11. Saia Inc
	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'SAIA' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date, 
            'Saia Inc' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE 'Saia%'
            OR [name] LIKE 'Linkex%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 12. Sirva Inc
	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
    SELECT DISTINCT 
            DOT_NUMBER, 
            [NAME] AS Child_Company, 
            'SIR' AS Stock_Ticker, 
            MAX(asofdate) AS as_of_date, 
            'Sirva Inc.' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
    WHERE([NAME] LIKE 'Sirva Relocation%'
            OR [NAME] LIKE 'North American Van Lines Inc%'
            OR [NAME] LIKE 'Allied Van Lines%'
            OR [NAME] LIKE 'Executive Relocation Corporation%'
            OR EMAILADDRESS LIKE '%@sirva.com%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 13. Daseke Inc

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
	SELECT DISTINCT 
			DOT_NUMBER, 
			[NAME] AS Child_Company, 
			'DSKE' AS Stock_Ticker, 
			MAX(asofdate) AS as_of_date, 
			'Daseke Inc.' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE([NAME] LIKE 'Alabama Carriers%'
			OR [NAME] LIKE 'Aveda Logistics%'
			OR [NAME] LIKE 'Aveda Transportation and Energy Services%'
			OR [NAME] LIKE 'Bed Rock Inc%'
			OR [NAME] LIKE 'Belmont Enterprises%'
			OR [NAME] LIKE 'Big Freight Systems%'
			OR [NAME] LIKE 'Boyd Bros Transportation%'
			OR [NAME] LIKE 'Boyd Logistics LLC%'
			OR [NAME] LIKE 'Builders Transportation Co%'
			OR [NAME] LIKE 'Bulldog Hiway%'
			OR [NAME] LIKE 'Central Oregon Truck Company%'
			OR [NAME] LIKE 'Daseke%'
			OR [NAME] LIKE 'Fleet Mover%'
			OR [NAME] LIKE 'Group One Inc%'
			OR [NAME] LIKE 'HODGES TRUCKING COMPANY LLC'--kf- needed!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			OR [NAME] LIKE 'Hornady Logistics LLC%'
			OR [NAME] LIKE 'Hornady Transportation%'
			OR [NAME] LIKE 'J Grady Randolph%'
			OR [NAME] LIKE 'JGR Logistics%'
			OR [NAME] LIKE 'Lone Star Transportation%'
			OR [NAME] LIKE 'LST Holdings%'
			OR [NAME] LIKE 'Mashburn Trucking Inc%'
			OR [NAME] LIKE 'Moore Freight Service%'
			OR [NAME] LIKE 'Naitonal Rigging%'
			OR [NAME] LIKE 'NEI Transport%'
			OR [NAME] LIKE 'R&R Trucking Inc%'
			OR [NAME] LIKE 'R & R Trucking Inc%'
			OR [NAME] LIKE 'Roadmaster Transportation%'
			OR [NAME] LIKE 'Roadmaster Specialized%'
			OR [NAME] LIKE 'Roadmaster Equipment Leasing%'
			OR [NAME] LIKE 'Rodan Transport%'
			OR [NAME] LIKE 'Schilli Distribution Services%'
			OR [NAME] LIKE 'Schilli Leasing%'
			OR [NAME] LIKE 'Schilli National Truck Leasing%'
			OR [NAME] LIKE 'Schilli Specialized%'
			OR [NAME] LIKE 'Schilli Transportation Services%'
			OR [NAME] LIKE 'SLT Express Way%'
			OR [NAME] LIKE 'Smokey Point Distributing%'
			OR [NAME] LIKE 'SPD Trucking LLC%'
			OR [NAME] LIKE 'Steelman Transportation%'
			OR [NAME] LIKE 'Tennessee Steel Haulers%'
			OR [NAME] LIKE 'TNI USA%'
			OR [NAME] LIKE 'WTI Transport Inc%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 14. Covenant Transportation Group Inc

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)

	SELECT DISTINCT 
		   DOT_NUMBER, 
		   [NAME] AS Child_Company, 
		   'CVTI' AS Stock_Ticker, 
		   MAX(asofdate) AS as_of_date, 
		   'Covenant Transport Inc' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE([NAME] LIKE 'Covenant Transport%'
		  OR [NAME] LIKE 'Southern Refrigerated Transport%'
		  OR [NAME] LIKE 'Star Transportation%'
		  OR [NAME] LIKE 'Landair Leasing%'
		  OR [NAME] LIKE 'Landair Logistics%'
		  OR [NAME] LIKE 'Transport Management Services%'
		  OR [NAME] LIKE 'Landair Transport%'
		  OR EMAILADDRESS LIKE '%@covenantlogistics.com%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 15. Heartland Express Inc

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
	SELECT DISTINCT 
		   DOT_NUMBER, 
		   [NAME] AS Child_Company, 
		   'HTLD' AS Stock_Ticker, 
		   MAX(asofdate) AS as_of_date, 
		   'Heartland Express Inc.' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE([NAME] LIKE 'Heartland Express%'
		  OR EMAILADDRESS LIKE '%@heartlandexpress.com')--kf- updating to heartlandEXPRESS
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

	-- 16. U.S. Xpress Enterprises 

	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
	SELECT DISTINCT 
		   DOT_NUMBER, 
		   [NAME] AS Child_Company, 
		   'USX' AS Stock_Ticker, 
		   MAX(asofdate) AS as_of_date,
		   CASE
			   WHEN [name] = 'XPRESS HOLDINGS LLC'
			   THEN 'US Xpress Enterprises'
			   WHEN [name] = 'US XPRESS CARGO INC'
			   THEN 'US Xpress Enterprises'
			   WHEN [name] = 'US XPRESS TRANSPORT CORP'
			   THEN 'US Xpress Enterprises'
			   WHEN [name] = 'U S XPRESS INC'
			   THEN 'US Xpress Enterprises'
			   WHEN [name] = 'XPRESS GLOBAL INC'
			   THEN 'US Xpress Enterprises'
			   WHEN [name] = 'USX GLOBAL CO'
			   THEN 'US Xpress Enterprises'
			   WHEN [name] = 'XPRESS GLOBAL SYSTEMS LLC'
			   THEN 'US Xpress Enterprises'
			   WHEN [name] = 'US XPRESS INC'
			   THEN 'US Xpress Enterprises'
			   WHEN([name] LIKE 'Mex Liner%'
					OR [name] LIKE 'Total Transportation of Mississippi%'
					OR [name] LIKE 'Total Logistics%')
			   THEN 'US Xpress Enterprises'
			   WHEN [name] = 'Xpress Internacional'			THEN 'US Xpress Enterprises'--kf added- 45 tractors 
			   ELSE NULL
		   END AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE([NAME] LIKE '%US Xpress%'
		  OR [NAME] LIKE '%USX%'
		  OR [NAME] LIKE '%USXpress%'
		  OR [NAME] LIKE '%U.S. Xpress%'
		  OR [NAME] LIKE '%U.S.Xpress%'
		  OR [NAME] LIKE '%U S Xpress%'
		  OR [NAME] LIKE '%Xpress Holdings%'
		  OR [NAME] LIKE '%Xpress Air%'
		  OR [NAME] LIKE '%Xpress Global%'
		  OR [NAME] LIKE '%Xpress Company%'
		  OR EMAILADDRESS LIKE '%@usxpress%')
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

-- 17. SNDR - not getting in!
	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
	SELECT DISTINCT 
			DOT_NUMBER, 
			[NAME] AS Child_Company, 
			'SNDR' AS Stock_Ticker, 
			MAX(asofdate) AS as_of_date, 
			'Schneider National, Inc.' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE [NAME] LIKE 'Schneider National%'
			OR [name] LIKE 'Schneider Logistic%'
			OR [name] LIKE 'Lodeso %'
			OR [name] LIKE 'Schneider Transport%'
			OR [name] LIKE 'Watkins & Shepard Trucking%' 
			OR [name] like 'WATKINS AND SHEPARD TRUCKING INC'--kf
			or [name] like 'SCHNEIDER IEP INC' --kf
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

--18. Marten Transport
	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
	SELECT DISTINCT 
			DOT_NUMBER, 
			[NAME] AS Child_Company, 
			'MRTN' AS Stock_Ticker, 
			MAX(asofdate) AS as_of_date, 
			'Marten Transport, Ltd.' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE [NAME] LIKE 'Marten Transport%' 
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

--19. USAK
	INSERT INTO #temp
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
	SELECT DISTINCT 
		   DOT_NUMBER, 
		   [NAME] AS Child_Company, 
		   'USAK' AS Stock_Ticker, 
		   MAX(asofdate) AS as_of_date, 
		   'USA Truck' AS Parent_Company,
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE [NAME] LIKE 'USA Truck%'
		  OR [name] LIKE 'Davis Transfer%'
		  OR [name] LIKE 'B & G Leasing%'
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

--20. CGIP
	-- KF: this should be CGIP not CGI 
	INSERT INTO #temp
	(DOT_Number, 
		Child_Company, 
		Stock_Ticker, 
		as_of_date, 
		Parent_Company,
		EMAILADDRESS,
		tract_tot
	)	 
	SELECT DISTINCT 
		DOT_NUMBER, 
		[NAME] AS Child_Company, 
		'CGIP' AS Stock_Ticker, 
		MAX(asofdate) AS as_of_date, 
		'Celadon Group, Inc.' AS Parent_Company,--KF: updated stock_ticker from CGI to CGIP
			EMAILADDRESS,
			MAX(tract_totn) AS tract_tot
    FROM #all
	WHERE [NAME] LIKE 'Celadon%'
		OR [name] LIKE 'Hyndman Transport%'
		OR [name] LIKE 'Quality Companies%'
		OR [name] LIKE 'Yanke Group'
		OR [name] LIKE 'Tango Transport%'
		OR [name] LIKE 'Quality Business Services%'
		OR [name] LIKE 'Land Span%'
		OR [name] LIKE 'A&S Kinard Logistics%'
		OR [name] LIKE 'TruckersB2B%'
		OR [name] LIKE 'Rock Leasing%'
		OR [name] LIKE 'Taylor Express%'
    GROUP BY DOT_NUMBER, 
            [name],
			EMAILADDRESS
	ORDER BY [NAME]

-- check the ones that are added --keeping this in for investigation purposes:

--select*
--from #temp a
--left join (select *, 'orig' as [source] from Warehouse.dbo.FMCSA_census_parent_child) b
--on a.DOT_Number=b.DOT_NUMBER
--where a.parent_company is not null


-- since we are doing 6 months back, we want to capture all, just append (not truncating)
	INSERT INTO Warehouse.dbo.FMCSA_census_parent_child
	(DOT_Number, 
	 Child_Company, 
	 Stock_Ticker, 
	 as_of_date, 
	 Parent_Company,
	 EMAILADDRESS,
	 tract_tot
	)
		   SELECT DOT_Number, 
				  Child_Company, 
				  Stock_Ticker, 
				  as_of_date, 
				  Parent_Company,
				  EMAILADDRESS,
				  tract_tot
		   FROM #temp
		   WHERE Parent_Company IS NOT NULL; --kf: I do not understand why the 'where' statement is different than the parent_company code above, resulting in NULLs. Good task for an intern/someone. Could further filter on tract_tot>0 if we cared about saving space

	DROP TABLE IF EXISTS #TEMP

END




