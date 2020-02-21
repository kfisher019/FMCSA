# Author: Kate Fisher
# Date: Sep 2019
# Purpose: backfill history based on cots change log. history here: warehouse.dbo.cots_census_changes_all_kf


rm(list=ls())
if (!require("pacman")) install.packages("pacman", repos = "http://cran.us.r-project.org")
pacman::p_load(dplyr,purrr,stringr,lubridate,reshape2,ggplot2,tidyr,geosphere,TTR,zoo,tidyverse,GGally,MASS,forecast,tseries,odbc,gridExtra,fUnitRoots)

library('nnet')
library(stringr)
library('odbc')
library('stringr')

#connect to sql warehouse
cn<- dbConnect(odbc(),Driver = "SQL Server",Server = "freightwaves.ctaqnedkuefm.us-east-2.rds.amazonaws.com",
               Database = "Warehouse",UID = "kate_fisher",
               PWD = "I4mKD*0E0Hvf&%13",
               Port = 1433)

# cn<- dbConnect(odbc(),Driver = "SQL Server",Server = "freightwaves.ctaqnedkuefm.us-east-2.rds.amazonaws.com",
#                Database = "Warehouse",UID = "fwdbmain",
#                PWD = "7AC?Ls9_z3W#@XrR",
#                Port = 1433)

cs<- dbConnect(odbc(),Driver = "SQL Server",Server = "freightwaves.ctaqnedkuefm.us-east-2.rds.amazonaws.com",
               Database = "Staging",UID = "fwdbmain",
               PWD = "7AC?Ls9_z3W#@XrR",
               Port = 1433)

cots_orig <- dbGetQuery(cn,"SELECT [id]
      ,[cots_census_id]
      ,[census_num]
      ,cast([enteredByDT] as date) as enteredByDT
      ,cast([updatedByDT] as date) as updatedByDT
      ,[change_xml] FROM [Warehouse].[dbo].[cots_census_changes_full]
       WHERE change_xml like '%owntract%' or change_xml like '%new_trptract%' or change_xml like '%new_trmtract%' or change_xml like '%act_stat%' 
       or change_xml like '%mlg150%' or change_xml like '%class%' or change_xml like '%iccdocket%' or change_xml like '%household%' or change_xml like '%fleetsize%'
                   or change_xml like '%crrinter%' or change_xml like '%crrhmintra%' or change_xml like '%crrintra%' or change_xml like '%shipinter%' or change_xml like '%shipintra%'")

cens_orig <- dbGetQuery(cn,"select 	 a.id, a.census_num,  a.adddate, a.deldate, a.enteredbydt
	 ,a.mcsipdate
	 ,a.chngdate,a.createdate, a.updatedbydt
	 ,a.[owntract]
	 ,a.[trptract]
 	 ,a.[trmtract]
	 ,a.act_stat
	 ,a.mlg150
	 ,a.class
	 ,a.iccdocket1
	 ,a.iccdocket2
	 ,a.fleetsize	 
	 ,a.household 
	 ,a.crrinter
	 ,a.crrhmintra
	 ,a.crrintra
	 ,a.shipinter
	 ,a.shipintra
	 ,a.iccdocket3	 from [Warehouse].[dbo].[cots_census] a")


# cens <- cens_tick #if just want the IDs from the 20 stock_tickers
  cens <- cens_orig
# cots <- cots_orig[which(cots_orig$census_num%in%cens$census_num),]#just the census_nums of interest
  cots <- cots_orig
  
# grab values between variables of interest

 cots$new_mlg150     <- str_match(cots$change_xml, "<mlg150>(.*?)</mlg150>")[,2]
 cots$new_owntract   <- str_match(cots$change_xml, "<owntract>(.*?)</owntract>")[,2]
 cots$new_trptract   <- str_match(cots$change_xml, "<trptract>(.*?)</trptract>")[,2]
 cots$new_trmtract   <- str_match(cots$change_xml, "<trmtract>(.*?)</trmtract>")[,2]
 cots$new_act_stat   <- str_match(cots$change_xml, "<act_stat>(.*?)</act_stat>")[,2]
 cots$new_fleetsize  <- str_match(cots$change_xml, "<fleetsize>(.*?)</fleetsize>")[,2]
 cots$new_class      <- str_match(cots$change_xml, "<class>(.*?)</class>")[,2]
 cots$new_iccdocket1 <- str_match(cots$change_xml, "<iccdocket1>(.*?)</iccdocket1>")[,2]
 cots$new_iccdocket2 <- str_match(cots$change_xml, "<iccdocket2>(.*?)</iccdocket2>")[,2]
 cots$new_iccdocket3 <- str_match(cots$change_xml, "<iccdocket3>(.*?)</iccdocket3>")[,2]
 cots$new_household  <- str_match(cots$change_xml, "<household>(.*?)</household>")[,2]
 cots$new_crrinter   <- str_match(cots$change_xml, "<crrinter>(.*?)</crrinter>")[,2]
 cots$new_crrhmintra <- str_match(cots$change_xml, "<crrhmintra>(.*?)</crrhmintra>")[,2]
 cots$new_crrintra   <- str_match(cots$change_xml, "<crrintra>(.*?)</crrintra>")[,2]
 cots$new_shipinter  <- str_match(cots$change_xml, "<shipinter>(.*?)</shipinter>")[,2]
 cots$new_shipintra  <- str_match(cots$change_xml, "<shipintra>(.*?)</shipintra>")[,2]

# change to dates
 cots$enteredByDT <- as.Date(cots$enteredByDT,format=c('%Y-%m-%d'))
 cots$updatedByDT <- as.Date(cots$updatedByDT,format=c('%Y-%m-%d'))

# change formats
 cens$adddate     <- as.Date(cens$adddate, format=c('%Y%m%d'))
 cens$enteredbydt <- as.Date(cens$enteredbydt, format=c('%Y-%m-%d'))
 cens$updatedbydt <- as.Date(cens$updatedbydt, format=c('%Y-%m-%d'))
 cens$chngdate    <- as.Date(cens$chngdate, format=c('%Y%m%d'))
 cens$createdate  <- as.Date(cens$createdate, format=c('%Y%m%d'))
 cens$census_num  <- trimws(cens$census_num,which='both')
 cens$class       <- trimws(cens$class,which='both')
 cens$iccdocket1  <- trimws(cens$iccdocket1,which='both')
 cens$iccdocket2  <- trimws(cens$iccdocket2,which='both')
 cens$iccdocket3  <- trimws(cens$iccdocket3,which='both')
 cens$mlg150    <- as.numeric(as.character(cens$mlg150))
 cens$owntract  <- as.numeric(as.character(cens$owntract))
 cens$trptract  <- as.numeric(as.character(cens$trptract))
 cens$trmtract  <- as.numeric(as.character(cens$trmtract))


# alternatively- all changes, not just tractor counts
# add an additional line with the 'current' values from cots_census
   cots1 <- cots[,-which(names(cots)%in%c('cots_census_id','change_xml'))]#removing the big vars
   cc <- cens[,c('id', 'census_num','enteredbydt','updatedbydt','mlg150','owntract','trptract','trmtract','act_stat','class','iccdocket1','iccdocket2','iccdocket3','household','crrinter','crrhmintra','crrintra','shipinter','shipintra','fleetsize')]
   cc$id <- NA # don't want to mess with ID stuff since it's 2 separate datasets
   names(cc) <- c('id', 'census_num','enteredByDT','updatedByDT','new_mlg150','new_owntract','new_trptract','new_trmtract','new_act_stat','new_class','new_iccdocket1','new_iccdocket2','new_iccdocket3','new_household','new_crrinter','new_crrhmintra','new_crrintra','new_shipinter','new_shipintra','new_fleetsize')
   setdiff(names(cc), names(cots1))
   cc <- cc[, names(cots1)]#reorder columns before rbind
   
   cots1[which(cots1$census_num=='2553037'),]
   cc[which(cc$census_num=='2553037'),]
   
   cots2 <- rbind(cots1,cc[which(cc$census_num%in%unique(cots1$census_num)),])
   cots2[which(cots2$census_num=='2553037'),]  

# add createdate and adddate and other variables from the main cots_census history
   cots3 <- merge(cots2, cens[,c('census_num','adddate','createdate','updatedbydt','enteredbydt','act_stat')], by='census_num')
   names(cots3)[which(names(cots3)=='enteredByDT')] <- 'enterCHG'
   names(cots3)[which(names(cots3)=='updatedByDT')] <- 'updateCHG'  
   names(cots3)[which(names(cots3)=='enteredbydt')] <- 'enterCENS'
   names(cots3)[which(names(cots3)=='updatedbydt')] <- 'updateCENS' 
   
   cots3[which(cots3$census_num=='2553037'),]
   
# # looking at data
#    ff <- cots3[which(cots3$updateCENS<cots3$updateCHG),]
#    ff$updateCENS-ff$updateCHG # updatedbydt from census is before the last updatedByDT in the change log- but max 4 days. if before then add 1 to updatedByDT - just leave as is and fill in based on updatedByDT
# 
#    dayspostcreate <- cens$updatedbydt-cens$createdate
   
# get max date by census_num
   d = aggregate(cots3$updateCHG,by=list(cots3$census_num),max)
   names(d) <- c('census_num','maxUpDT')
   cots4 <- merge(cots3, d, by='census_num')
   
# replace the updateByDT to the max updatedByDT+1 for the records that are from the cots_census, to ensure it is the last record...else the inactive/active stuff is messed up, and we want to ensure the last record is the one that turns it 'inactive'- 
# check ff$updatedByDT-ff$updatedbydt to make sure this is very small difference! right now= 4 day max
   cots4$updateCHG[which(cots4$updateCHG<=cots4$maxUpDT & is.na(cots4$id))] <- cots4$maxUpDT[which(cots4$updateCHG<=cots4$maxUpDT & is.na(cots4$id))] +1
   cots4$updateCHG <- as.Date(cots4$updateCHG, format=c('%Y-%m-%d'))
   cots4[which(cots4$census_num=='2553037'),] 
   # should be over 8636012 records
   
# --------------#   
# ---> LOCB <---#
# --------------# 
# if the value in change_xml is the old value
   
# fill in last observation carried forward in reverse? 
   cots4 <- cots4[order(cots4$census_num,cots4$updateCHG, decreasing=TRUE),]# in reverse
   #cots4 <- cots4[order(cots4$census_num,cots4$updateCHG, decreasing=FALSE),]# LOCF
   

   LOCB <- function(id, x) {
      x[cummax(((!is.na(x)) | c(TRUE, id[-1] != id[-length(id)])) * seq_along(x))]
   }
   cots4$new_mlg150_2   <- LOCB(cots4$census_num,cots4$new_mlg150)   
   cots4$new_owntract_2 <- LOCB(cots4$census_num,cots4$new_owntract)   
   cots4$new_trmtract_2 <- LOCB(cots4$census_num,cots4$new_trmtract)  
   cots4$new_trptract_2 <- LOCB(cots4$census_num,cots4$new_trptract)  
   cots4$new_act_stat_2 <- LOCB(cots4$census_num,cots4$new_act_stat)
   cots4$new_class_2    <- LOCB(cots4$census_num,cots4$new_class)
   cots4$new_iccdocket1_2 <- LOCB(cots4$census_num,cots4$new_iccdocket1)
   cots4$new_iccdocket2_2 <- LOCB(cots4$census_num,cots4$new_iccdocket2)
   cots4$new_iccdocket3_2 <- LOCB(cots4$census_num,cots4$new_iccdocket3)
   cots4$new_household_2  <- LOCB(cots4$census_num,cots4$new_household)
   cots4$new_crrinter_2   <- LOCB(cots4$census_num,cots4$new_crrinter)
   cots4$new_crrhmintra_2 <- LOCB(cots4$census_num,cots4$new_crrhmintra)
   cots4$new_crrintra_2   <- LOCB(cots4$census_num,cots4$new_crrintra)
   cots4$new_shipinter_2  <- LOCB(cots4$census_num,cots4$new_shipinter)
   cots4$new_shipintra_2  <- LOCB(cots4$census_num,cots4$new_shipintra)

  
# the start date is the lag of the updatedByDT
   cots4 <- cots4[order(cots4$census_num,cots4$updateCHG),]
   
# start date didn't work! must add in sql- done
   #cots4$start_date <- as.Date(c(NA, cots4$updateCHG[-nrow(cots4)]))
   #cots4$start_date[which(!duplicated(cots4$census_num))] <- NA
   #cots4$start_date[which(is.na(cots4$start_date))] <- cots4$adddate[which(is.na(cots4$start_date))]
   
   cots4$end_date <- cots4$updateCHG-1 # end date of that value is the date
   cots4$ntract <- as.numeric(as.character(cots4$new_owntract_2)) + as.numeric(as.character(cots4$new_trmtract_2)) + as.numeric(as.character(cots4$new_trptract_2))
   
   write.csv(cots4, file = "C:\\Users\\Kate Fisher\\OneDrive\\FMCSA\\csv_from_r\\cots_change_for_all_changes_v1.csv",row.names=FALSE)
   odbc::dbWriteTable(cn, "cots_census_changes_all_kf", cots4, overwrite=TRUE) #exporting to warehouse

   #--> check the intervals for start_date and end_date <--#
#---> must do fleetsize since it wasn't originally added <---#
   
   df <- read.csv(file="C:\\Users\\Kate Fisher\\OneDrive\\FMCSA\\csv_from_r\\cots_change_for_all_changes_v1.csv")#,nrows=20)
   
   df[1:40, c('census_num','updateCHG1','updateCHG','updateCENS','adddate','start_date','end_date','new_act_stat_2','maxUpDT')]
   #999969, 999965, 999974, 999979, 999998   
   df[df$census_num%in%c('999969', '999965', '999974', '999979', '999998'), c('id','census_num','updateCHG','updateCENS','adddate','end_date','new_act_stat_2','maxUpDT')]   
   # the end date should add 1 if id is NA and updateCENS
   df_orig <- df
   # # get max date by census_num
   # d = aggregate(df$updateCENS,by=list(cots3$census_num),max)
   # names(d) <- c('census_num','maxUpDT')
   # cots4 <- merge(cots3, d, by='census_num')
   

   df[which(df$census_num=='2553037'),]  
   df <- df[order(df$census_num,df$updateCHG),]
   df[which(df$census_num=='2553037'),]
   df$updateCHG1 <- as.Date(as.character(df$updateCHG), format='%Y-%m-%d')
   df$updateCENS <- as.Date(as.character(df$updateCENS), format='%Y-%m-%d')
   df$updateCHG <- as.Date(as.character(df$updateCHG), format='%Y-%m-%d')
   # to replace with a day later 
   ind0 <- intersect(which(is.na(df$id)), which(df$updateCENS<=df$updateCHG))
   
   # get max date by census_num
   d = aggregate(df$updateCHG,by=list(df$census_num),max)
   names(d) <- c('census_num','maxUpDT')
   df1 <- merge(df, d, by='census_num')
   df1$updateCHG1[which(df1$updateCHG1<=df1$maxUpDT.y & is.na(df1$id))] <- df1$maxUpDT.y[which(df1$updateCHG1<=df1$maxUpDT.y & is.na(df1$id))] +1
   df1$updateCHG1 <- as.Date(df1$updateCHG1, format=c('%Y-%m-%d'))
   df1[which(df1$census_num=='2553037'),]   
   df1[df1$census_num%in%c('999969', '999965', '999974', '999979', '999998'), c('id','census_num','updateCHG','updateCENS','adddate','end_date','new_act_stat_2','maxUpDT.y','maxUpDT.x','updateCHG1')]    
   df1[which(df1$census_num%in%df$census_num[ind0[1:5]]), c('id','census_num','updateCHG1','updateCHG','updateCENS','adddate','end_date','new_act_stat_2','maxUpDT')]
   
   
   # length(ind0)
   # df$updateCHG1[which(is.na(df$id)&df$updateCENS<=df$updateCHG))]
   # df$start_date <- c(as.Date('1974-06-01', format=c('%Y-%m-%d')),df$updateCHG1[-nrow(df)])
   # df$start_date[which(!duplicated(df$census_num))] <- NA
   # df$start_date[which(is.na(df$start_date))] <- df$adddate[which(is.na(df$start_date))]   
   # 
   # df[which(df$census_num%in%fleet$census_num[ind1[1:5]]), c('census_num','updateCHG1','updateCHG','updateCENS','adddate','start_date','end_date','new_act_stat_2','maxUpDT')]
   # 
   # df[1:40, c('census_num','updateCHG1','updateCHG','updateCENS','adddate','start_date','end_date','new_act_stat_2','maxUpDT')]
   # 
   # fleet <- dbGetQuery(cn,"select [id], [census_num], [new_fleetsize],[start_date], [end_date],[updateCHG],[maxUpDT],[new_act_stat],[new_act_stat_2],
   # adddate,createdate,updatedbydt,enteredbydt,act_stat,updateCHG,updateCENS
   # FROM [Warehouse].[dbo].[cots_census_changes_all_kf]")
   # 
   # ind1 <- which(fleet$end_date<=fleet$start_date)
   # 
   # fleet1 <- fleet[order(fleet$census_num,fleet$updateCHG, decreasing=TRUE),]# in reverse

   df1 <- df1[order(df1$census_num,df1$updateCHG1, decreasing=TRUE),]  
   df1[which(df1$census_num=='2553037'),]   
   
   LOCB <- function(id, x) {
     x[cummax(((!is.na(x)) | c(TRUE, id[-1] != id[-length(id)])) * seq_along(x))]
   }
   
   df1$new_fleetsize_2    <- LOCB(df1$census_num,df1$new_fleetsize) 
   df1$new_mlg150_2   <- LOCB(df1$census_num,df1$new_mlg150)   
   df1$new_owntract_2 <- LOCB(df1$census_num,df1$new_owntract)   
   df1$new_trmtract_2 <- LOCB(df1$census_num,df1$new_trmtract)  
   df1$new_trptract_2 <- LOCB(df1$census_num,df1$new_trptract)  
   df1$new_act_stat_2 <- LOCB(df1$census_num,df1$new_act_stat)
   df1$new_class_2    <- LOCB(df1$census_num,df1$new_class)
   df1$new_iccdocket1_2 <- LOCB(df1$census_num,df1$new_iccdocket1)
   df1$new_iccdocket2_2 <- LOCB(df1$census_num,df1$new_iccdocket2)
   df1$new_iccdocket3_2 <- LOCB(df1$census_num,df1$new_iccdocket3)
   df1$new_household_2  <- LOCB(df1$census_num,df1$new_household)
   df1$new_crrinter_2   <- LOCB(df1$census_num,df1$new_crrinter)
   df1$new_crrhmintra_2 <- LOCB(df1$census_num,df1$new_crrhmintra)
   df1$new_crrintra_2   <- LOCB(df1$census_num,df1$new_crrintra)
   df1$new_shipinter_2  <- LOCB(df1$census_num,df1$new_shipinter)
   df1$new_shipintra_2  <- LOCB(df1$census_num,df1$new_shipintra)
   
   df1[which(df1$census_num=='2553037'),]   
   
   
# the start date is the lag of the updatedByDT
   df1 <- df1[order(df1$census_num,df1$updateCHG1),]
   
#start date 
   df1$start_date <- c(as.Date('1974-06-01', format=c('%Y-%m-%d')),df1$updateCHG1[-nrow(df1)])
   df1$start_date[which(!duplicated(df1$census_num))] <- NA
   df1$start_date[which(is.na(df1$start_date))] <- df1$adddate[which(is.na(df1$start_date))]
   df1$end_date <- df1$updateCHG1-1 # end date of that value is the date
   df1$ntract <- as.numeric(as.character(df1$new_owntract_2)) + as.numeric(as.character(df1$new_trmtract_2)) + as.numeric(as.character(df1$new_trptract_2))
   df1[1:30, c('id','census_num','updateCHG','updateCHG1','maxUpDT.y','start_date','end_date','end_date_old','new_act_stat_2')]
   df2 <- df1[,-which(names(df1)%in%c('end_date_old','updateCHG','maxUpDT.x'))]
   
   write.csv(df2, file = "C:\\Users\\Kate Fisher\\OneDrive\\FMCSA\\csv_from_r\\cots_change_for_all_changes_v2.csv",row.names=FALSE)
   odbc::dbWriteTable(cn, "cots_census_changes_all_kf_v2", df2, overwrite=TRUE) #exporting to warehouse

      
   
 length(which(is.na(df1$new_fleetsize_2)))  
