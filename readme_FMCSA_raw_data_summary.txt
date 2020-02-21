1. All raw data that is transferred will be saved in some non-warehouse location (ask Eric/Brandon where this should be)
2. What is to be saved in warehouse:

	appended every month
Warehouse.dbo.FMCSA_Census  

	all of 2019 should be truncated and repopulated - based on 
Warehouse.dbo.FMCSA_Insp - INSP_DATE
warehouse.dbo.FMCSA_Crash_Master - REPORT_DATE
Warehouse.dbo.FMCSA_Insp_Unit - delete and replace the inspection IDs with an insp_date in 2019
Warehouse.dbo.FMCSA_Insp_Viol - delete and replace the inspection IDs with an insp_date in 2019

	extra tables- may use eventually? - If possible, I would truncate and repopulate 2019 - based on whatever [CRASH_ID],[INSPECTION_ID], or [INSP_VIOLATION_ID]s in the 2019 folder
FMCSA_Crash_Carrier
FMCSA_Crash_Event
FMCSA_Insp_Carrier
FMCSA_Insp_Part_Section
FMCSA_Insp_Study
FMCSA_Insp_Supp_Viol
FMCSA_Insp_Viol_Ship
FMCSA_Violations - is this given to us?
FMCSA_Unprocessed_VINS - is this given to us?
FMCSA_VINS - is this given to us?

alex-created static tables:
Warehouse.dbo.Interstate_Miles_by_State (side note: when and how often does this need to be updated? currently we use the same number for 2013 to present. Not sure how this was created initially. Good intern task.)
Warehouse.dbo.FMCSA_Basic

kate-created static tables:
Warehouse.dbo.FMCSA_VIOLATION_CODES 
Warehouse.dbo.FMCSA_Federal_Violation_Codes

?