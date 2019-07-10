library(frm)
library(zoo)
library(fun)
library(data.table)
library(rapport)
library(sapply)
library(fastDummies)
library(dplyr)
library(tidyr)
library(base)
library(datetime)
library(openxlsx)
library(lmtest)
library(estimatr)
library(ggplot2)
library(lattice)


#####################IMPORTING DATA SETS##########################################################
#dat
"Importing data set processed for neural networks "
final_data_file <- read.csv( "final_data.csv", header = TRUE) 

#NALoc_dat
"Importing data from raw files: NA Location Performance Data "
NALoc_data <- as.data.frame(read.xlsx( "NA Location Performance Data.xlsx", colNames = TRUE) )

"Importing NA Reviews Data from raw files "
NAReviews_data <-  read.csv("Copy of NA Reviews Data.csv", header = TRUE) 

'Rename the columns to exclude "..."'
colnames(NAReviews_data)[colnames(NAReviews_data)=="ï..Id..Review."] <- "Id..Review."
colnames(NAReviews_data)[colnames(NAReviews_data)=="X"] <- "Review"


#################PROCESSING AND VARIABLES MANIPULATION - Agreggating location information into final data set##########################################

'Creating Locational data to be named: LocData with specific information to be needed in the proposed models'
LocData <- subset.data.frame(cbind(NALoc_data[1:2], NALoc_data[6], NALoc_data[8:9]))

'Taking empty information out of the data set and renaming the Id column to represent IdLocation'
LocData[LocData==""]  <- NA 
colnames(LocData)[colnames(LocData)=="Id"] <- "Location.Id"

'Uses IDLocation, POI, NAME to merge properly into "final_data_file_2" -  a new data frame created to include location information'
final_data_file_2 <- merge(x = final_data_file, y = LocData, all.x = TRUE,by = cbind("Location.Id", "Name", "Connectors_site"))

'Renaming the columns to exclude non-standard characters'
colnames(final_data_file_2)[colnames(final_data_file_2)=="Has.DCFC?"] <- "DCFC"
colnames(final_data_file_2)[colnames(final_data_file_2)=="Has.J-1772?"] <- "J1772"

#################PROCESSING AND VARIABLES MANIPULATION - New Final data set from the final_data_file_2 with only the information needed for the proposed models ##########################################
new_data_file <- as.data.frame(cbind(final_data_file_2[1:8],final_data_file_2[10:11], final_data_file_2[14],final_data_file_2[24], final_data_file_2[72:76], final_data_file_2[34]))
#127257 obs of 18 variables

'Change Review Year formatting'
new_data_file$ReviewYear <-format(as.Date(as.character(new_data_file$Created.At..Review.), format= "%m/%d/%y %I:%M:%S %p")
                            ,"%Y")
new_data_file$RYear <- as.numeric(new_data_file$ReviewYear)
new_data_file$ReviewYear <- NULL

'Creating a variable that counts the checkins+writtenreview'
new_data_file$check_WR <- 1

#################PROCESSING AND VARIABLES MANIPULATION - Preparing NAReviews_data information to be merged into the new_data_file created above##########################################
'Empty information as NA'
NAReviews_data[NAReviews_data==""]  <- NA 

'Subsetting specific variables from NAReviews'
temp_NAReviews <- subset.data.frame(cbind(NAReviews_data[1:2],NAReviews_data[5], NAReviews_data[4], NAReviews_data[9]))

'Review Year formatting is changed to match the new_data_file formatting'
temp_NAReviews$ReviewYear <-format(as.Date(as.character(temp_NAReviews$Created.At..Review.), format= "%m/%d/%y %I:%M:%S %p")
                                          ,"%Y")
temp_NAReviews$RYear <- as.numeric(temp_NAReviews$ReviewYear)

'Cleaning empty observations'
temp_NAReviews <- temp_NAReviews[!is.na(temp_NAReviews$Id..Review.),]

'Computing number of checkins without writtenreview'
temp_NAReviews$check_Not_WR <- 1

'Excluding duplicated or non-standard variables'
temp_NAReviews$Created.At..Review. <- NULL
temp_NAReviews$ReviewYear <- NULL

'Merge into the new_data_file'
new_data_file_plus <- merge(x=temp_NAReviews,y=new_data_file,by= cbind("Id..Review.", "User.Id", "Location.Id", "RYear"), all.x =TRUE)

'Create a variable that represent the sum of checkins without written review'
new_data_file_plus$check_NotWR_plus_WR_SUM <- NA
new_data_file_plus$check_NotWR_plus_WR_SUM <- as.numeric(new_data_file_plus$check_NotWR_plus_WR_SUM)
new_data_file_plus$check_NotWR_plus_WR_SUM <- rowSums(new_data_file_plus[,c("check_Not_WR", "check_WR")], na.rm=TRUE)
new_data_file_plus$check_NotWR_plus_WR_SUM <-ifelse(new_data_file_plus$check_NotWR_plus_WR_SUM > 0,1,0)

'Aggregating by ID the count of checkins with written or not reviews'

'Using two temporary datasets to aggregate'
'For  checkins with or without written reviews'
temp1 <- subset.data.frame(cbind(new_data_file_plus[1],new_data_file_plus[3:4], new_data_file_plus[23]))
temp_count_byID_sum_allcheckins <- aggregate(check_NotWR_plus_WR_SUM ~ Location.Id + RYear, FUN=sum, data = temp1) 
colnames(temp_count_byID_sum_allcheckins)[colnames(temp_count_byID_sum_allcheckins)=="check_NotWR_plus_WR_SUM"] <- "Total_checkins_ALL_byID"


'For checkins only with written reviews'
temp2 <- subset.data.frame(cbind(new_data_file_plus[1],new_data_file_plus[3:4], new_data_file_plus[22]))
temp_count_byID_sum_onlyWRcheckins <- aggregate(check_WR ~ Location.Id + RYear, FUN=sum, data = temp2) 
colnames(temp_count_byID_sum_onlyWRcheckins)[colnames(temp_count_byID_sum_onlyWRcheckins)=="check_WR"] <- "Total_checkins_OnlyWR_byID"


'Aggregate to the new_data_file'
new_data_file <- left_join(new_data_file,temp_count_byID_sum_allcheckins, by= c("Location.Id", "RYear"))
new_data_file <- left_join(new_data_file,temp_count_byID_sum_onlyWRcheckins, by= c("Location.Id", "RYear"))

#########Creating New Vatiables (Conectors, Networks, Urban and Rural....) as an Input for The Proposed Models###############################

'Point of Interest Factors variable'
new_data_file$POI <- as.numeric(as.factor(new_data_file$bestPOIGroup))

'Connectors Factors variable'
new_data_file$CONN <- as.character(new_data_file$Connectors_site)

#######
'Creating connectors dummies'
'Tesla Supercharger'
new_data_file$TeslaSupercharger <- NA
new_data_file$TeslaSupercharger <-ifelse(((grepl('Tesla Supercharger', new_data_file$CONN, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="TeslaSupercharger"] <- "Dummy_TeslaSupercharger"

'CCS (SAE Combo)'
new_data_file$CCS_SAECombo<- NA
new_data_file$CCS_SAECombo<-ifelse(((grepl("CCS (SAE Combo)", new_data_file$CONN, fixed = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="CCS_SAECombo"] <- "Dummy_CCS_SAECombo"

'Wall Outlet'
new_data_file$WallOutlet <- NA
new_data_file$WallOutlet<-ifelse(((grepl('Wall Outlet', new_data_file$CONN, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="WallOutlet"] <- "Dummy_WallOutlet"

'Tesla Roadster'
new_data_file$TeslaRoadster <- NA
new_data_file$TeslaRoadster <-ifelse(((grepl('Tesla Roadster',new_data_file$CONN, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="TeslaRoadster"] <- "Dummy_TeslaRoadster"

'CHAdeMO'
new_data_file$CHAdeMO<- NA
new_data_file$CHAdeMO<-ifelse(((grepl('CHAdeMO', new_data_file$CONN, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="CHAdeMO"] <- "Dummy_CHAdeMO"

'Tesla Model S'
new_data_file$TeslaModel_S <- NA
new_data_file$TeslaModel_S<-ifelse(((grepl('Tesla Model S', new_data_file$CONN, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="TeslaModel_S"] <- "Dummy_TeslaModel_S"

'J-1772'
new_data_file$J_1772 <- NA
new_data_file$J_1772<-ifelse(((grepl('J-1772',new_data_file$CONN, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="J_1772"] <- "Dummy_J_1772"

'NEMA Plug 240v'
new_data_file$NEMA_Plug_240v <- NA
new_data_file$NEMA_Plug_240v<-ifelse(((grepl('NEMA Plug 240v', new_data_file$CONN, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="NEMA_Plug_240v"] <- "Dummy_NEMA_Plug_240v"

'other'
new_data_file$other <- NA
new_data_file$other<-ifelse(((grepl('other', new_data_file$CONN, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="other"] <- "Dummy_other"

'Total Connectors'
new_data_file$Total_Connectors <- NA
new_data_file$Total_Connectors = rowSums(new_data_file[, c(25:33)])



######
'Creating Networks dummies'
'Total Networks'
new_data_file$NET <- NA ; new_data_file$NET <- as.character(new_data_file$Networks_site)
new_data_file$Total_NETWORKS <- NA
new_data_file$Total_NETWORKS <- ifelse(is.na(new_data_file$NET),1, 
                                       (count.fields(textConnection(new_data_file$NET),sep = ",")))
'Charge Point'
new_data_file$ChargePoint<- NA
new_data_file$ChargePoint<-ifelse(((grepl('ChargePoint', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="ChargePoint"] <- "Dummy_ChargePoint"

'Car Charging'
new_data_file$CarCharging<- NA
new_data_file$CarCharging<-ifelse(((grepl('CarCharging', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="CarCharging"] <- "Dummy_CarCharging"

'Blink'
new_data_file$Blink<- NA
new_data_file$Blink <-ifelse(((grepl('Blink', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="Blink"] <- "Dummy_Blink"

'GewattStation'
new_data_file$GEWattStation<- NA
new_data_file$GEWattStation <-ifelse(((grepl('GE WattStation', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="GEWattStation"] <- "Dummy_GEWattStation"

'EVgo'
new_data_file$EVgo<- NA
new_data_file$EVgo <-ifelse(((grepl('EVgo', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="EVgo"] <- "Dummy_EVgo"

'GreenLots'
new_data_file$Greenlots<- NA
new_data_file$Greenlots <-ifelse(((grepl('Greenlots', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="Greenlots"] <- "Dummy_Greenlots"

'Shorepower'
new_data_file$Shorepower<- NA
new_data_file$Shorepower <-ifelse(((grepl('Shorepower', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="Shorepower"] <- "Dummy_Shorepower"

'Aerovironment'
new_data_file$AeroVironment<- NA
new_data_file$AeroVironment <-ifelse(((grepl('AeroVironment', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="AeroVironment"] <- "Dummy_AeroVironment"

'SemaCharge'
new_data_file$SemaCharge<- NA
new_data_file$SemaCharge <-ifelse(((grepl('SemaCharge', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="SemaCharge"] <- "Dummy_SemaCharge"

'SuperCharger'
new_data_file$NetSuperCharger<- NA
new_data_file$NetSuperCharger <-ifelse(((grepl('SuperCharger', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="NetSuperCharger"] <- "Dummy_NetSuperCharger"

'JNSH'
new_data_file$JNSH<- NA
new_data_file$JNSH <-ifelse(((grepl('JNSH', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="JNSH"] <- "Dummy_JNSH"

'Destination'
new_data_file$Destination<- NA
new_data_file$Destination <-ifelse(((grepl('Destination', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="Destination"] <- "Dummy_Destination"

'Volta'
new_data_file$Volta<- NA
new_data_file$Volta <-ifelse(((grepl('Volta', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="Volta"] <- "Dummy_Volta"

'RechargeAccess'
new_data_file$RechargeAccess<- NA
new_data_file$RechargeAccess <-ifelse(((grepl('RechargeAccess', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="RechargeAccess"] <- "Dummy_RechargeAccess"

'SunCountry'
new_data_file$SunCountry<- NA
new_data_file$SunCountry <-ifelse(((grepl('Sun Country', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="SunCountry"] <- "Dummy_SunCountry"

'DOEAFDC'
new_data_file$DOEAFDC<- NA
new_data_file$DOEAFDC <-ifelse(((grepl('DOE AFDC', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="DOEAFDC"] <- "Dummy_DOEAFDC"

'RWE'
new_data_file$RWE<- NA
new_data_file$RWE <-ifelse(((grepl('RWE', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="RWE"] <- "Dummy_RWE"

'OpConnect'
new_data_file$OpConnect<- NA
new_data_file$OpConnect <-ifelse(((grepl('OpConnect', new_data_file$NET, ignore.case = TRUE))),1,0)
colnames(new_data_file)[colnames(new_data_file)=="OpConnect"] <- "Dummy_OpConnect"

new_data_file$PrivateNet<- NA
new_data_file$PrivateNet <-ifelse(is.na(new_data_file$NET),1,0)
colnames(new_data_file)[colnames(new_data_file)=="PrivateNet"] <- "Dummy_PrivateNet"


#####
'Urban and Non-Urban center'
'Aggregating by Location Id'
subset_UrbInfo <- subset.data.frame(cbind(final_data_file[1:2],final_data_file[4], final_data_file[71]))
new_data_file <- left_join(new_data_file,subset_UrbInfo, by= c("Location.Id", "Id..Review.","User.Id"))

new_data_file <-  dummy_cols(new_data_file, select_columns = "urbanRural")
colnames(new_data_file)[colnames(new_data_file)=="urbanRural_2"] <- "DUrban_Center"
colnames(new_data_file)[colnames(new_data_file)=="urbanRural_1"] <- "DUrban_Cluster"
colnames(new_data_file)[colnames(new_data_file)=="urbanRural_0"] <- "DRural"


#####
'Dummy Predicted Sentiment'
new_data_file$PredSent <- as.numeric(as.factor(new_data_file$Predicted.Sentiment))
new_data_file <- dummy_cols(new_data_file, select_columns = "Predicted.Sentiment")
colnames(new_data_file)[colnames(new_data_file)=="Predicted.Sentiment_NEGATIVE"] <- "Dummy_NEGATIVE"
colnames(new_data_file)[colnames(new_data_file)=="Predicted.Sentiment_POSITIVE"] <- "Dummy_POSITIVE"

#####
'Dummy Public Private'
new_data_file$publicPrivate <- as.character(new_data_file$publicPrivate)
new_data_file <- dummy_cols(new_data_file, select_columns = "publicPrivate")
colnames(new_data_file)[colnames(new_data_file)=="publicPrivate_Private"] <- "Dummy_PRIVATE"
colnames(new_data_file)[colnames(new_data_file)=="publicPrivate_Public"] <- "Dummy_PUBLIC"
'Variable 0 or 1 if public or private'
new_data_file$PP <- as.numeric(as.factor(new_data_file$publicPrivate))

#####
'Quality Rating'
new_data_file$PlugScore[is.na(new_data_file$PlugScore)] <- 0
new_data_file$PlugScore_Levels <- NA
new_data_file$PlugScore_Levels <-cut(new_data_file$PlugScore, c(0,1,5,7,9,11), right=FALSE, labels = c("No PlugScore","Very Poor", "Poor", "Fair", "Excellent"))

new_data_file$QualityRating <- NA
new_data_file$QualityRating <- new_data_file$PlugScore_Levels
levels(new_data_file$QualityRating) <- 0:4
new_data_file$QualityRating <- as.numeric(new_data_file$QualityRating)

#####
'BestPOIGroup dummies'
new_data_file <- dummy_cols(new_data_file, select_columns =  "bestPOIGroup")

###################Count Reviews and Negative Reviews Variable###############################

'Creating Count Negative Reviews Variable and checking missing information'
new_data_file$Review_Count_Negatives <-  (new_data_file$check_WR)*(new_data_file$Dummy_NEGATIVE)

'Review Rate aggregating considering if public or private'
'Review Rate Model considering ALL checkins: WReviews and Non-WReviews'
modelRR_1st <- aggregate(check_WR ~ RYear + Location.Id + PP, new_data_file, sum)
names(modelRR_1st)[4]<-"Review_Count_byID_PP"
new_data_file <- left_join(new_data_file,modelRR_1st, by= c("Location.Id", "RYear","PP"))
new_data_file$Review_Rate_ALL <- new_data_file$check_WR/new_data_file$Total_checkins_ALL_byID


'Review Rate Model considering only checkins with written reviews'
new_data_file$Review_Rate_OnlyWR <- new_data_file$check_WR/new_data_file$Total_checkins_OnlyWR_byID


'Negative Review model considering only checkins with written review'
modelNR_2nd <- aggregate(Review_Count_Negatives ~ RYear + Location.Id + PP, new_data_file, sum)
names(modelNR_2nd)[4]<-"NEG_SUMbyID_PP"
new_data_file <- left_join(new_data_file,modelNR_2nd, by= c("Location.Id", "RYear","PP"))
new_data_file$Neg_Score <- new_data_file$NEG_SUMbyID_PP/new_data_file$Review_Count_byID_PP

###################Renaming and changing variable type#######################################
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Car Dealership"] <- "bestPOIGroup_Car_Dealership"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Car Rental"] <- "bestPOIGroup_Car_Rental"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Convenience Store/Gas Station"] <- "bestPOIGroup_Convenience_Gas_Station"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Parking Garage/Lot"] <- "bestPOIGroup_Parking_Garage_Lot"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Place of Worship"] <- "bestPOIGroup_Place_Worship"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_RV Park"] <- "bestPOIGroup_RV_Park"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Shopping Center"] <- "bestPOIGroup_Shopping_Center"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Street Parking"] <- "bestPOIGroup_Street_Parking"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Transit Station"] <- "bestPOIGroup_Transit_Station"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Visitor Center"] <- "bestPOIGroup_Visitor_Center"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Hotel/Lodging"] <- "bestPOIGroup_Hotel_Lodging"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Restaurant/Food"] <- "bestPOIGroup_Restaurant_Food"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Restaurant/Food"] <- "bestPOIGroup_Restaurant_Food"
colnames(new_data_file)[colnames(new_data_file)=="bestPOIGroup_Government"] <- "Dummy_Government"
new_data_file$bestPOIGroup_services <- NULL

#Changing variable type
new_data_file$bestPOIGroup_Airport <- as.numeric(new_data_file$bestPOIGroup_Airport)
new_data_file$bestPOIGroup_Car_Dealership <- as.numeric(new_data_file$bestPOIGroup_Car_Dealership)
new_data_file$bestPOIGroup_Car_Rental <- as.numeric(new_data_file$bestPOIGroup_Car_Rental)
new_data_file$bestPOIGroup_Convenience_Gas_Station <- as.numeric(new_data_file$bestPOIGroup_Convenience_Gas_Station)
new_data_file$bestPOIGroup_Education <- as.numeric(new_data_file$bestPOIGroup_Education)
new_data_file$bestPOIGroup_Entertainment <- as.numeric(new_data_file$bestPOIGroup_Entertainment)
new_data_file$Dummy_Government <- as.numeric(new_data_file$Dummy_Government)
new_data_file$bestPOIGroup_Hotel_Lodging <- as.numeric(new_data_file$bestPOIGroup_Hotel_Lodging)
new_data_file$bestPOIGroup_Healthcare <- as.numeric(new_data_file$bestPOIGroup_Healthcare)
new_data_file$bestPOIGroup_Library <- as.numeric(new_data_file$bestPOIGroup_Library)
new_data_file$bestPOIGroup_Other <- as.numeric(new_data_file$bestPOIGroup_Other)
new_data_file$bestPOIGroup_Outdoor <- as.numeric(new_data_file$bestPOIGroup_Outdoor)
new_data_file$bestPOIGroup_Parking_Garage_Lot <- as.numeric(new_data_file$bestPOIGroup_Parking_Garage_Lot)
new_data_file$bestPOIGroup_Place_Worship <- as.numeric(new_data_file$bestPOIGroup_Place_Worship)
new_data_file$bestPOIGroup_Residential <- as.numeric(new_data_file$bestPOIGroup_Residential)
new_data_file$bestPOIGroup_Restaurant_Food <- as.numeric(new_data_file$bestPOIGroup_Restaurant_Food)
new_data_file$bestPOIGroup_RV_Park <- as.numeric(new_data_file$bestPOIGroup_RV_Park)
new_data_file$bestPOIGroup_Services <- as.numeric(new_data_file$bestPOIGroup_Services)
new_data_file$bestPOIGroup_Shopping <- as.numeric(new_data_file$bestPOIGroup_Shopping)
new_data_file$bestPOIGroup_Shopping_Center <- as.numeric(new_data_file$bestPOIGroup_Shopping_Center)
new_data_file$bestPOIGroup_Street_Parking <- as.numeric(new_data_file$bestPOIGroup_Street_Parking)
new_data_file$bestPOIGroup_Supermarket <- as.numeric(new_data_file$bestPOIGroup_Supermarket)
new_data_file$bestPOIGroup_Transit_Station <- as.numeric(new_data_file$bestPOIGroup_Transit_Station)
new_data_file$bestPOIGroup_Unknown <- as.numeric(new_data_file$bestPOIGroup_Unknown)
new_data_file$bestPOIGroup_Visitor_Center <- as.numeric(new_data_file$bestPOIGroup_Visitor_Center)
new_data_file$bestPOIGroup_Workplace <- as.numeric(new_data_file$bestPOIGroup_Workplace)

######################Removing data sets from global environment############################
rm(LocData)
rm(NALoc_data)
rm(NAReviews_data)
rm(modelNR_2nd)
rm(modelRR_1st)
rm(new_data_file_plus)
rm(final_data_file_2)
rm(final_data_file)
rm(temp_count_byID_sum_allcheckins)
rm(temp_count_byID_sum_onlyWRcheckins)
rm(temp1)
rm(temp2)
rm(temp_NAReviews)
rm(subset_UrbInfo)

######################Histograms#############################################################
#Histogram by Point Of Interest 
histogram( ~ Review_Rate | bestPOIGroup , data=new_dat, 
           layout=c(3,9) , scales= list(y=list(relation="free"),
                                        x=list(relation="free") ) )

histogram( ~ Neg_Score | bestPOIGroup , data=new_dat, 
           layout=c(3,9) , scales= list(y=list(relation="free"),
                                        x=list(relation="free") ) )


#Histogram for Review Rate
'Checkins with written reviews Histogram'
ggplot(new_data_file, aes(Review_Rate_OnlyWR)) +
  geom_histogram(binwidth = 0.01, col="black", 
                 fill="grey") + 
  ggtitle(expression(atop("Histogram for Review Rate", 
                           atop(italic("Only Checkins with written reviews      "), ""))))+
  
    labs(x="Review Rate", y="Count") +
  theme(panel.background = element_rect(fill = 'white', colour = 'grey'), 
        plot.title = element_text(size=12), plot.subtitle = element_text(size = 10))
  

'All Checkins Histogram'
ggplot(new_data_file, aes(Review_Rate_ALL)) +
  geom_histogram(binwidth = 0.01, col="black", 
                 fill="grey") + 
  ggtitle(expression(atop("Histogram for Review Rate"
                          , atop(italic("Checkins                                              "), ""))))+
  
  labs(x="Review Rate", y="Count") +
  theme(panel.background = element_rect(fill = 'white', colour = 'grey'), 
        plot.title = element_text(size=12), plot.subtitle = element_text(size = 10))


#Histogram for Negativity Score
ggplot(new_data_file, aes(Neg_Score)) +
  geom_histogram(binwidth = 0.01, col="black", 
                 fill="grey") + 
  ggtitle(expression(atop("Histogram for Negativity Score")))+
  
  labs(x="Negativity Score", y="Count") +
  theme(panel.background = element_rect(fill = 'white', colour = 'grey'), 
        plot.title = element_text(size=12), plot.subtitle = element_text(size = 10))

##################################################################################################
####################Fractional Response Models####################################################
########################################Review Rate ALL###########################################
##################################################################################################
#####Table 6 Model FRM (1)
y <- new_data_file$Review_Rate_ALL
xmain1 <- new_data_file[,c("DUrban_Center", "DRural" ,"Dummy_PUBLIC",
                          
                          "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                          "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                          "bestPOIGroup_Hotel_Lodging", 
                          "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                          "bestPOIGroup_Car_Dealership",
                          "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                          "bestPOIGroup_Convenience_Gas_Station",
                          "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                          "bestPOIGroup_Outdoor",
                          "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                          "bestPOIGroup_Place_Worship",
                          "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                          "bestPOIGroup_Street_Parking",	
                          "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                          
                          "Total_Connectors","Total_NETWORKS"
                          
                          
                          
)]

mainfrm1 <- frm(y , xmain1 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres1 <- frm.pe(mainfrm1)

###################################################################################################
#####Table 6 Model FRM (2)
y <- new_data_file$Review_Rate_ALL
xmain2 <- new_data_file[,c("DUrban_Center", "DRural","Dummy_PUBLIC",
                          
                          "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                          "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                          "bestPOIGroup_Hotel_Lodging", 
                          "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                          "bestPOIGroup_Car_Dealership",
                          "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                          "bestPOIGroup_Convenience_Gas_Station",
                          "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                          "bestPOIGroup_Outdoor",
                          "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                          "bestPOIGroup_Place_Worship",
                          "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                          "bestPOIGroup_Street_Parking",	
                          "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                          
                          "Total_Connectors","Total_NETWORKS",
                          "QualityRating"
                          
)]

mainfrm2 <- frm(y , xmain2 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres2 <- frm.pe(mainfrm2)

####################################################################################################
#####Table 6 Model FRM (3)
y <- new_data_file$Review_Rate_ALL
xmain3 <- new_data_file[,c("DUrban_Center", "DRural","Dummy_Government",
                          
                          "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                          "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                          "bestPOIGroup_Hotel_Lodging", 
                          "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                          "bestPOIGroup_Car_Dealership",
                          "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                          "bestPOIGroup_Convenience_Gas_Station",
                          "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                          "bestPOIGroup_Outdoor",
                          "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                          "bestPOIGroup_Place_Worship",
                          "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                          "bestPOIGroup_Street_Parking",	
                          "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                          
                          "Total_Connectors","Total_NETWORKS",
                          "QualityRating"
                          
)]

mainfrm3 <- frm(y , xmain3 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres3 <- frm.pe(mainfrm3)

#####################################################################################################
#####Table 6 Model FRM (4)
y <- new_data_file$Neg_Score
xmain4 <- new_data_file[,c("DUrban_Center", "DRural","Dummy_PUBLIC",
                          
                          "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                          "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                          "bestPOIGroup_Hotel_Lodging",
                          "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                          "bestPOIGroup_Car_Dealership",
                          "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                          "bestPOIGroup_Convenience_Gas_Station",
                          "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                          "bestPOIGroup_Outdoor",
                          "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                          "bestPOIGroup_Place_Worship",
                          "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                          "bestPOIGroup_Street_Parking",	
                          "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                          
                          "Total_Connectors","Total_NETWORKS"
                          
                          
                          
)]

mainfrm4 <- frm(y , xmain4 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres4 <- frm.pe(mainfrm4)
###################################################################################################
#####Table 6 Model FRM (5)
y <- new_data_file$Neg_Score
xmain5 <- new_data_file[,c("DUrban_Center", "DRural","Dummy_PUBLIC",
                          
                          "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                          "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                          "bestPOIGroup_Hotel_Lodging", 
                          "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                          "bestPOIGroup_Car_Dealership",
                          "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                          "bestPOIGroup_Convenience_Gas_Station",
                          "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                          "bestPOIGroup_Outdoor",
                          "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                          "bestPOIGroup_Place_Worship",
                          "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                          "bestPOIGroup_Street_Parking",	
                          "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                          
                          "Total_Connectors","Total_NETWORKS", "QualityRating"
                          
                          
                          
)]

mainfrm5 <- frm(y , xmain5 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres5 <- frm.pe(mainfrm5)

###################################################################################################
#####Table 6 Model FRM (6)
y <- new_data_file$Neg_Score
xmain6 <- new_data_file[,c("DUrban_Center", "DRural","Dummy_Government",
                          
                          "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                          "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                          "bestPOIGroup_Hotel_Lodging", 
                          "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                          "bestPOIGroup_Car_Dealership",
                          "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                          "bestPOIGroup_Convenience_Gas_Station",
                          "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                          "bestPOIGroup_Outdoor",
                          "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                          "bestPOIGroup_Place_Worship",
                          "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                          "bestPOIGroup_Street_Parking",	
                          "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                          
                          "Total_Connectors","Total_NETWORKS", "QualityRating"
                          
                          
                          
)]

mainfrm6 <- frm(y , xmain6 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres6 <- frm.pe(mainfrm6)


###################################################################################################
#####Table 7 Model FRM (1)
y <- new_data_file$Review_Rate_ALL
xmain7_1 <- new_data_file[,c("DUrban_Center", "DRural", "Dummy_PUBLIC" ,"Dummy_Government",
                            
                            "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                            "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                            "bestPOIGroup_Hotel_Lodging", 
                            "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                            "bestPOIGroup_Car_Dealership",
                            "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                            "bestPOIGroup_Convenience_Gas_Station",
                            "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                            "bestPOIGroup_Outdoor",
                            "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                            "bestPOIGroup_Place_Worship",
                            "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                            "bestPOIGroup_Street_Parking",	
                            "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                            
                            "Total_Connectors","Total_NETWORKS", "QualityRating"
                            
                            
                            
)]

mainfrm7_1 <- frm(y , xmain7_1 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres7_1 <- frm.pe(mainfrm7_1)

###################################################################################################
#####Table 7 Model OLS (1)
lmo_rrate7_1 <- lm(Review_Rate_ALL  ~ DUrban_Center + DRural + Dummy_PUBLIC + Dummy_Government 
                   
                   +bestPOIGroup_Residential+bestPOIGroup_Shopping
                   +bestPOIGroup_Restaurant_Food+bestPOIGroup_Healthcare
                   +bestPOIGroup_Hotel_Lodging
                   +bestPOIGroup_Workplace+bestPOIGroup_Supermarket	
                   +bestPOIGroup_Car_Dealership
                   +bestPOIGroup_Education+bestPOIGroup_Entertainment 
                   +bestPOIGroup_Convenience_Gas_Station
                   +bestPOIGroup_Transit_Station+bestPOIGroup_RV_Park
                   +bestPOIGroup_Outdoor
                   +bestPOIGroup_Airport+bestPOIGroup_Services	
                   +bestPOIGroup_Place_Worship
                   +bestPOIGroup_Shopping_Center+bestPOIGroup_Library	
                   +bestPOIGroup_Street_Parking	
                   +bestPOIGroup_Visitor_Center+bestPOIGroup_Car_Rental+bestPOIGroup_Other
                   
                   +Total_Connectors+Total_NETWORKS+QualityRating  - 1, data = new_data_file)



#same results as lm.cluster
lmo_rrate_cluster7_1 <- commarobust(lmo_rrate7_1, se_type = "CR0", clusters = new_data_file$Location.Id)
summary(lmo_rrate_cluster7_1)
coeftest(lmo_rrate_cluster7_1)

###################################################################################################
#####Table 7 Model FRM (2)
y <- new_data_file$Neg_Score
xmain7_2 <- new_data_file[,c("DUrban_Center", "DRural", "Dummy_PUBLIC" ,"Dummy_Government",
                            
                            "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                            "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                            "bestPOIGroup_Hotel_Lodging", 
                            "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                            "bestPOIGroup_Car_Dealership",
                            "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                            "bestPOIGroup_Convenience_Gas_Station",
                            "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                            "bestPOIGroup_Outdoor",
                            "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                            "bestPOIGroup_Place_Worship",
                            "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                            "bestPOIGroup_Street_Parking",	
                            "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                            
                            "Total_Connectors","Total_NETWORKS", "QualityRating"
                            
                            
                            
)]

mainfrm7_2 <- frm(y , xmain7_2 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres7_2 <- frm.pe(mainfrm7_2)

##################################################################################################
#####Table 7 Model OLS (1)
lmo_rrate7_2 <- lm(Neg_Score  ~ DUrban_Center + DRural + Dummy_PUBLIC + Dummy_Government 
                   
                   +bestPOIGroup_Residential+bestPOIGroup_Shopping
                   +bestPOIGroup_Restaurant_Food+bestPOIGroup_Healthcare
                   +bestPOIGroup_Hotel_Lodging
                   +bestPOIGroup_Workplace+bestPOIGroup_Supermarket	
                   +bestPOIGroup_Car_Dealership
                   +bestPOIGroup_Education+bestPOIGroup_Entertainment 
                   +bestPOIGroup_Convenience_Gas_Station
                   +bestPOIGroup_Transit_Station+bestPOIGroup_RV_Park
                   +bestPOIGroup_Outdoor
                   +bestPOIGroup_Airport+bestPOIGroup_Services	
                   +bestPOIGroup_Place_Worship
                   +bestPOIGroup_Shopping_Center+bestPOIGroup_Library	
                   +bestPOIGroup_Street_Parking	
                   +bestPOIGroup_Visitor_Center+bestPOIGroup_Car_Rental+bestPOIGroup_Other
                   
                   +Total_Connectors+Total_NETWORKS+QualityRating  - 1, data = new_data_file)



#same results as lm.cluster
lmo_rrate_cluster7_2 <- commarobust(lmo_rrate7_2, se_type = "CR0", clusters = new_data_file$Location.Id)
summary(lmo_rrate_cluster7_2)
coeftest(lmo_rrate_cluster7_2)

##################################################################################################
####################Fractional Response Models####################################################
########################################Review Rate Only Written Reviews left#####################
##################################################################################################


#####Table 8 Model FRM (1)
y <- new_data_file$Review_Rate_OnlyWR
xmain1 <- new_data_file[,c("DUrban_Center", "DRural" ,"Dummy_PUBLIC",
                           
                           "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                           "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                           "bestPOIGroup_Hotel_Lodging", 
                           "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                           "bestPOIGroup_Car_Dealership",
                           "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                           "bestPOIGroup_Convenience_Gas_Station",
                           "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                           "bestPOIGroup_Outdoor",
                           "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                           "bestPOIGroup_Place_Worship",
                           "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                           "bestPOIGroup_Street_Parking",	
                           "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                           
                           "Total_Connectors","Total_NETWORKS"
                           
                           
                           
)]

mainfrm1 <- frm(y , xmain1 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres1 <- frm.pe(mainfrm1)

###################################################################################################
#####Table 8 Model FRM (2)
y <- new_data_file$Review_Rate_OnlyWR
xmain2 <- new_data_file[,c("DUrban_Center", "DRural","Dummy_PUBLIC",
                           
                           "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                           "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                           "bestPOIGroup_Hotel_Lodging", 
                           "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                           "bestPOIGroup_Car_Dealership",
                           "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                           "bestPOIGroup_Convenience_Gas_Station",
                           "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                           "bestPOIGroup_Outdoor",
                           "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                           "bestPOIGroup_Place_Worship",
                           "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                           "bestPOIGroup_Street_Parking",	
                           "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                           
                           "Total_Connectors","Total_NETWORKS",
                           "QualityRating"
                           
)]

mainfrm2 <- frm(y , xmain2 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres2 <- frm.pe(mainfrm2)

####################################################################################################
#####Table 8 Model FRM (3)
y <- new_data_file$Review_Rate_OnlyWR
xmain3 <- new_data_file[,c("DUrban_Center", "DRural","Dummy_Government",
                           
                           "bestPOIGroup_Residential", "bestPOIGroup_Shopping"	, 
                           "bestPOIGroup_Restaurant_Food" , "bestPOIGroup_Healthcare", 
                           "bestPOIGroup_Hotel_Lodging", 
                           "bestPOIGroup_Workplace", "bestPOIGroup_Supermarket",	
                           "bestPOIGroup_Car_Dealership",
                           "bestPOIGroup_Education", "bestPOIGroup_Entertainment", 
                           "bestPOIGroup_Convenience_Gas_Station",
                           "bestPOIGroup_Transit_Station",	"bestPOIGroup_RV_Park",	
                           "bestPOIGroup_Outdoor",
                           "bestPOIGroup_Airport", "bestPOIGroup_Services",	
                           "bestPOIGroup_Place_Worship",
                           "bestPOIGroup_Shopping_Center", "bestPOIGroup_Library",	
                           "bestPOIGroup_Street_Parking",	
                           "bestPOIGroup_Visitor_Center",	"bestPOIGroup_Car_Rental","bestPOIGroup_Other",
                           
                           "Total_Connectors","Total_NETWORKS",
                           "QualityRating"
                           
)]

mainfrm3 <- frm(y , xmain3 , linkfrac = 'logit', var.type =  "cluster", var.cluster = new_data_file$Location.Id)
mainres3 <- frm.pe(mainfrm3)


