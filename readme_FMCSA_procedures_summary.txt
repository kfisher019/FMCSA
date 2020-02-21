Kate Fisher
Sep 23, 2109
Summary of FMCSA procedures

---------------------------------------------------------------------------------------------------------------------------------------------
[dbo].[create_APS_APHS_FATL_INJ] - rewrites 6 months of data (by state and USA)
Data:
	all of 2019 should be truncated and repopulated (code should work with just appending, too)
	warehouse.dbo.FMCSA_Crash_Master
---------------------------------------------------------------------------------------------------------------------------------------------
[dbo].[create_VIO_VIOH_VIORAT_OOS_OOSH_OSVI] - rewrites 6 months of data (by state and USA)
Data:
	all of 2019 should be truncated and repopulated (code should work with just appending, too)
	Warehouse.dbo.FMCSA_Insp
	Warehouse.dbo.FMCSA_Insp_Unit
static tables:
	Warehouse.dbo.Interstate_Miles_by_State - when and how often does this need to be updated? 
		currently we use the same number for 2013 to present. Not sure how this was created initially. Good intern task.
---------------------------------------------------------------------------------------------------------------------------------------------
[dbo].[create_VIOBasics] - rewrites 6 months of data (by state and USA)
Data:	
	all of 2019 should be truncated and repopulated (code should work with just appending, too)
	Warehouse.dbo.FMCSA_Insp
	Warehouse.dbo.FMCSA_Insp_Unit
	Warehouse.dbo.FMCSA_Insp_Viol should probably be in here
static tables:
	Warehouse.dbo.FMCSA_Basic - basic group. This was created by Alex. Manually created. Intern/junior task if wanted to update.
	Warehouse.dbo.FMCSA_MCMIS_VIOLATION_CATEGORIES - created by me from FMCSA website. not sure how often needs to be updated 
		C:\\Users\\Kate Fisher\\OneDrive\\FMCSA\\raw_data_inspec_crash\\inspection_code_groupings\\VIOLATION_CATEGORIES.csv'
		from: https://ask.fmcsa.dot.gov/app/mcmiscatalog/d_inspection5 (last update 2014)
	Warehouse.dbo.FMCSA_Federal_Violation_Codes - was this created by me. not sure how often needs to be updated
		C:\\Users\\Kate Fisher\\OneDrive\\FMCSA\\raw_data_inspec_crash\\inspection_code_groupings\\FMCSA_Federal_Violation_Codes.txt
---------------------------------------------------------------------------------------------------------------------------------------------
[dbo].[create_FMCSA_Census_Tickers] (tractor counts and fleet counts and fleet counts by size in 'for hire')- appends one month
Data: 	
	Warehouse.dbo.FMCSA_Census -- appended every month
---------------------------------------------------------------------------------------------------------------------------------------------
[dbo].[create_FMCSA_census_parent_child] - procedure updates this dataset: Warehouse.dbo.FMCSA_census_parent_child (assigns child to parent)
					   I added a few missing companies. If we wanted, Intern/junior/market expert task: 
						to update to correct 2 types of errors: 
						1)we were assigning child companies to parents that shouldn't be 
						2)we were missing child companies.
Data:	Warehouse.dbo.FMCSA_Census: Looks through the new appended FMCSA_census records for all child companies that contribute to a 
	parent company, and adds tot_tract to see if it would contribute to denominator (and numerator) anyway 
	(e.g. large tot_tract counts should be checked to make sure they really belong to the parent company)
---------------------------------------------------------------------------------------------------------------------------------------------
[dbo].[create_INSPT_VIOT_OOST_ACDTT_FATLT_INJT] (crashes and violations per 20 stock company tickers/'parent') - appends every month
Data:
	Warehouse.dbo.FMCSA_Census
	Warehouse.dbo.FMCSA_census_parent_child - created by [dbo].[create_FMCSA_Census_Tickers] 
---------------------------------------------------------------------------------------------------------------------------------------------

