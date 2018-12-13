library(frm)
library(zoo)
library(fun)
library(data.table)
library(rapport)
library(sapply)
#install.packages("data.table")
#install.packages("base")
#install.packages("fastDummies")
library(fastDummies)
#install.packages("cquad")
library(dplyr)
library(tidyr)
library(base)
#install.packages("flipTime")
library(datetime)
#Sys.setlocale("LC_TIME", "C")
library(openxlsx)

#Manipulated data set 
dat <- read.csv( "https://www.dropbox.com/s/vmj5g0g9h8yansw/final_data.csv?dl=1", header = TRUE) 
#127257 obs

#NA Location Performance Data RAW : Get Has DCFC and Has J-177, merge by ID that is Location ID ???
NALP_dat <- read.xlsx( "https://www.dropbox.com/s/jcm1m789wde2q33/NA%20Location%20Performance%20Data.xlsx?dl=1", colNames = TRUE) 
NALoc_dat <- as.data.frame(NALP_dat)
#20303 obs
#> unique(factor(dat$bestPOIGroup))
#[1] Shopping                      Parking Garage/Lot            Place of Worship             
#[4] Supermarket                   Convenience Store/Gas Station Restaurant/Food              
#[7] Residential                   Government                    Hotel/Lodging                
#[10] Services                      Car Dealership                Workplace                    
#[13] Entertainment                 Transit Station               Education                    
#[16] RV Park                       Outdoor                       Airport                      
#[19] Visitor Center                Healthcare                    Shopping Center              
#[22] Unknown                       Street Parking                Library                      
#[25] Other                         services                      Car Rental                   
#27 Levels: Airport Car Dealership Car Rental Convenience Store/Gas Station ... Workplace
#> unique(factor(NALoc_dat$`POI.(group)`))
#[1] Parking Garage/Lot Other              Residential                          
#[5] Shopping Center    Restaurant         Hotel/Lodging      Government        
#[9] Workplace          Store              Park               Dealership        
#[13] School/University  Healthcare        
#14 Levels:  Dealership Government Healthcare Hotel/Lodging Other Park ... Workplace


#Get the blank and count the reviews
NAReviews_dat <-  read.csv("https://www.dropbox.com/s/aei3kfzxsdgmodh/Copy%20of%20NA%20Reviews%20Data.csv?dl=1", header = TRUE) 
#276749 obs
colnames(NAReviews_dat)[colnames(NAReviews_dat)=="ï..Id..Review."] <- "Id..Review."
colnames(NAReviews_dat)[colnames(NAReviews_dat)=="X"] <- "Review"

########MERGE LocDat with dat matching IDLocation, POI, NAME############
LocData <- subset.data.frame(cbind(NALoc_dat[1:2], NALoc_dat[6], NALoc_dat[8:9]))
LocData[LocData==""]  <- NA 
sum(is.na(LocData$Id)) #0
sum(is.na(LocData$Name)) #0
sum(is.na(LocData$Connectors_site)) #0
sum(is.na(LocData$`Has.DCFC?`)) #0
sum(is.na(LocData$`Has.J-1772?`)) #0

colnames(LocData)[colnames(LocData)=="Id"] <- "Location.Id"

dat2 <- merge(x = dat, y = LocData, all.x = TRUE,by = cbind("Location.Id", "Name", "Connectors_site"))
sum(is.na(dat2$`Has.DCFC?`)) #4890
#(20303-4890) = 15413 not found

colnames(dat2)[colnames(dat2)=="Has.DCFC?"] <- "DCFC"
colnames(dat2)[colnames(dat2)=="Has.J-1772?"] <- "J1772"


#############Creating a new data set with the variables of interest###################
which( colnames(dat2)=="PlugScore" )

new_dat <- as.data.frame(cbind(dat2[1:8],dat2[10:11], dat2[14],dat2[24], dat2[72:76], dat2[34]))
new_dat$ReviewYear <-format(as.Date(as.character(new_dat$Created.At..Review.), format= "%m/%d/%y %I:%M:%S %p")
                            ,"%Y")
new_dat$RYear <- as.numeric(new_dat$ReviewYear)
new_dat$ReviewYear <- NULL
#127257 obs
new_dat$RC <- 1

################### Manipulating NA Reviews to merge###############
NAReviews_dat[NAReviews_dat==""]  <- NA 
subset_temp_NAReviews <- subset.data.frame(cbind(NAReviews_dat[1:2],NAReviews_dat[5], NAReviews_dat[4], NAReviews_dat[9]))
#####Year######
subset_temp_NAReviews$ReviewYear <-format(as.Date(as.character(subset_temp_NAReviews$Created.At..Review.), format= "%m/%d/%y %I:%M:%S %p")
                            ,"%Y")
subset_temp_NAReviews$RYear <- as.numeric(subset_temp_NAReviews$ReviewYear)

#Taking Id Reviews with NAs
subset_temp_NAReviews <- subset_temp_NAReviews[!is.na(subset_temp_NAReviews$Id..Review.),]
    #write.csv(subset_temp_NAReviews, file = "subset_temp_NAReviews.csv")
subset_temp_NAReviews$RC_count_NAReview <- 1
####################33Merging and keeping all the rows#################
subset_temp_NAReviews$Created.At..Review. <- NULL
subset_temp_NAReviews$ReviewYear <- NULL
new_dat_plus <- merge(x=subset_temp_NAReviews,y=new_dat,by= cbind("Id..Review.", "User.Id", "Location.Id", "RYear"), all.x =TRUE)
#write.csv(new_dat_plus, file = "new_dat_plus.csv")

#######################################################################################
new_dat_plus$RC_sum <- NA
new_dat_plus$RC_sum <- as.numeric(new_dat_plus$RC_sum)
#Summing up de counts and treat NA as 0
new_dat_plus$RC_sum <- rowSums(new_dat_plus[,c("RC_count_NAReview", "RC")], na.rm=TRUE)

#Getting the counts to 1 or 0
new_dat_plus$Review_VF_count <- NA
new_dat_plus$Review_VF_count <-ifelse(new_dat_plus$RC_sum > 0,1,0)
sum(new_dat_plus$Review_VF_count)
#276650


####AGREGATING BY ID LOCATION AND POI#####################
#new_dat_plus$RC_totalbyPOI <- NULL    #### DO NOT HAVE ALL POIs
new_dat_plus$RC_totalbyID <-  NA

sum(is.na(new_dat_plus$Id..Review.)) #0
sum(is.na(new_dat_plus$Location.Id))
sum(is.na(new_dat_plus$RYear))

temp <- subset.data.frame(cbind(new_dat_plus[1],new_dat_plus[3:4], new_dat_plus[24]))
temp_count_byID <- aggregate(Review_VF_count ~ Location.Id + RYear, FUN=sum, data = temp)  
colnames(temp_count_byID)[colnames(temp_count_byID)=="Review_VF_count"] <- "Total_RC_byID"

new_dat <- left_join(new_dat,temp_count_byID, by= c("Location.Id", "RYear"))
sum(is.na(new_dat$Total_RC_byID)) #0 

########################################################################################
#Checking for missing values
sum(is.na(new_dat$Predicted.Sentiment)) 
#Returned 0
sum(is.na(new_dat$publicPrivate)) 
#Returned 0
sum(is.na(new_dat$bestPOIGroup)) 
#Returned 0



########################################################################################
########################################################################################
#Creating New Variables for Input in the Model##########################################
########################################################################################
########################################################################################

#### POI ##########################################
new_dat$POI <- as.numeric(as.factor(new_dat$bestPOIGroup))

#####REVIEW YEAR##### To get timming for the review ### ALREADY CREATED BEFORE TO NEW_DAT
#d <- as.character(new_dat$Created.At..Review.[1]); d
#as.Date(d,format= "%m/%d/%y %I:%M:%S %p")
#new_dat$ReviewYear <-format(as.Date(as.character(new_dat$Created.At..Review.), format= "%m/%d/%y %I:%M:%S %p")
#,"%Y")
#new_dat$RYear <- as.numeric(new_dat$ReviewYear)


############Networks Variable##################################################################
#Consider NA = 1 and count how many connectors
sum(is.na(new_dat$Connectors_site))
#[1] 0
#Variable CONN is just to get the character transformation for factor to perform the matching##
new_dat$CONN <- as.character(new_dat$Connectors_site)
#"Tesla Supercharger"
#"CCS (SAE Combo)"
#'Wall Outlet"
#'Tesla Roadster"
#"CHAdeMO"
#"Tesla Model S"
#"J-1772"
#"NEMA Plug 240v"
#"other"

#Tesla Supercharger###########################################################################
new_dat$TeslaSupercharger <- NA
  new_dat$TeslaSupercharger <-ifelse(((grepl('Tesla Supercharger', new_dat$CONN, ignore.case = TRUE))),1,0)

   #sum(new_dat$TeslaSupercharger )
      #5198
colnames(new_dat)[colnames(new_dat)=="TeslaSupercharger"] <- "Dummy_TeslaSupercharger"

#CCS (SAE Combo)##############################################################################
new_dat$CCS_SAECombo<- NA
  new_dat$CCS_SAECombo<-ifelse(((grepl("CCS (SAE Combo)", new_dat$CONN, fixed = TRUE))),1,0)

colnames(new_dat)[colnames(new_dat)=="CCS_SAECombo"] <- "Dummy_CCS_SAECombo"

#Wall Outlet################################################################################### 
new_dat$WallOutlet <- NA
  new_dat$WallOutlet<-ifelse(((grepl('Wall Outlet', new_dat$CONN, ignore.case = TRUE))),1,0)
  colnames(new_dat)[colnames(new_dat)=="WallOutlet"] <- "Dummy_WallOutlet"

  #Tesla Roadster################################################################################
new_dat$TeslaRoadster <- NA
  new_dat$TeslaRoadster <-ifelse(((grepl('Tesla Roadster', new_dat$CONN, ignore.case = TRUE))),1,0)
  colnames(new_dat)[colnames(new_dat)=="TeslaRoadster"] <- "Dummy_TeslaRoadster"
  
#CHAdeMO#####################################################################################
new_dat$CHAdeMO<- NA
  new_dat$CHAdeMO<-ifelse(((grepl('CHAdeMO', new_dat$CONN, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="CHAdeMO"] <- "Dummy_CHAdeMO"

#Tesla Model S################################################################################
new_dat$TeslaModel_S <- NA
  new_dat$TeslaModel_S<-ifelse(((grepl('Tesla Model S', new_dat$CONN, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="TeslaModel_S"] <- "Dummy_TeslaModel_S"

#J-1772#######################################################################################
new_dat$J_1772 <- NA
  new_dat$J_1772<-ifelse(((grepl('J-1772', new_dat$CONN, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="J_1772"] <- "Dummy_J_1772"

#NEMA Plug 240v###############################################################################
new_dat$NEMA_Plug_240v <- NA
  new_dat$NEMA_Plug_240v<-ifelse(((grepl('NEMA Plug 240v', new_dat$CONN, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="NEMA_Plug_240v"] <- "Dummy_NEMA_Plug_240v"

#other########################################################################################
new_dat$other <- NA
new_dat$other<-ifelse(((grepl('other', new_dat$CONN, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="other"] <- "Dummy_other"

###############Counting number of connectors#######################################
new_dat$TotalConnector <- NA
new_dat$TotalConnector = rowSums(new_dat[, c(24:32)])
which (colnames(new_dat)=="Dummy_TeslaSupercharger" )
which (colnames(new_dat)=="Dummy_other" )
####################################################################################
#write.csv(x, file = "c:\\myname\\yourfile.csv", row.names = FALSE)

####################################################################################
#NETWORKS
unique(factor(new_dat$Networks_site))
new_dat$NET <- NA
new_dat$NET <- as.character(new_dat$Networks_site)
new_dat$Total_NETWORKS <- NA
new_dat$Total_NETWORKS <- ifelse(is.na(new_dat$NET),1, 
                           (count.fields(textConnection(new_dat$NET),sep = ",")))
max(new_dat$Total_NETWORKS)
#3

new_dat$ChargePoint<- NA
new_dat$ChargePoint<-ifelse(((grepl('ChargePoint', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="ChargePoint"] <- "Dummy_ChargePoint"
################################
new_dat$CarCharging<- NA
new_dat$CarCharging<-ifelse(((grepl('CarCharging', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="CarCharging"] <- "Dummy_CarCharging"
################################
new_dat$Blink<- NA
new_dat$Blink <-ifelse(((grepl('Blink', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="Blink"] <- "Dummy_Blink"
################################
new_dat$GEWattStation<- NA
new_dat$GEWattStation <-ifelse(((grepl('GE WattStation', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="GEWattStation"] <- "Dummy_GEWattStation"
###############################
new_dat$EVgo<- NA
new_dat$EVgo <-ifelse(((grepl('EVgo', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="EVgo"] <- "Dummy_EVgo"
#############################
new_dat$Greenlots<- NA
new_dat$Greenlots <-ifelse(((grepl('Greenlots', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="Greenlots"] <- "Dummy_Greenlots"
#############################
new_dat$Shorepower<- NA
new_dat$Shorepower <-ifelse(((grepl('Shorepower', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="Shorepower"] <- "Dummy_Shorepower"
#############################
new_dat$AeroVironment<- NA
new_dat$AeroVironment <-ifelse(((grepl('AeroVironment', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="AeroVironment"] <- "Dummy_AeroVironment"
############################
new_dat$SemaCharge<- NA
new_dat$SemaCharge <-ifelse(((grepl('SemaCharge', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="SemaCharge"] <- "Dummy_SemaCharge"
############################
new_dat$NetSuperCharger<- NA
new_dat$NetSuperCharger <-ifelse(((grepl('SuperCharger', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="NetSuperCharger"] <- "Dummy_NetSuperCharger"
###########################
new_dat$JNSH<- NA
new_dat$JNSH <-ifelse(((grepl('JNSH', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="JNSH"] <- "Dummy_JNSH"
##########################
new_dat$Destination<- NA
new_dat$Destination <-ifelse(((grepl('Destination', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="Destination"] <- "Dummy_Destination"
##########################
new_dat$Volta<- NA
new_dat$Volta <-ifelse(((grepl('Volta', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="Volta"] <- "Dummy_Volta"
##########################
new_dat$RechargeAccess<- NA
new_dat$RechargeAccess <-ifelse(((grepl('RechargeAccess', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="RechargeAccess"] <- "Dummy_RechargeAccess"
##########################
new_dat$SunCountry<- NA
new_dat$SunCountry <-ifelse(((grepl('Sun Country', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="SunCountry"] <- "Dummy_SunCountry"

##########################
new_dat$DOEAFDC<- NA
new_dat$DOEAFDC <-ifelse(((grepl('DOE AFDC', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="DOEAFDC"] <- "Dummy_DOEAFDC"
##########################
new_dat$RWE<- NA
new_dat$RWE <-ifelse(((grepl('RWE', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="RWE"] <- "Dummy_RWE"
##########################
new_dat$OpConnect<- NA
new_dat$OpConnect <-ifelse(((grepl('OpConnect', new_dat$NET, ignore.case = TRUE))),1,0)
colnames(new_dat)[colnames(new_dat)=="OpConnect"] <- "Dummy_OpConnect"
###########################
new_dat$PrivateNet<- NA
new_dat$PrivateNet <-ifelse(is.na(new_dat$NET),1,0)
colnames(new_dat)[colnames(new_dat)=="PrivateNet"] <- "Dummy_PrivateNet"

####Check Total Connectors
new_dat$check <- NA 
new_dat$check <- rowSums(new_dat[, c(36:54)])
sum(new_dat$check - new_dat$Total_NETWORKS)
#0
sum(new_dat$Total_NETWORKS)
#130694
sum(new_dat$check)
#130694
which(colnames(new_dat)=="Dummy_ChargePoint" )
#36

which (colnames(new_dat)=="Dummy_PrivateNet" )
#54
sum(new_dat$TotalConnector)
#199844
#write.csv(new_dat, file = "new_dat.csv")
####################################################################################
subset_newdat2 <- subset.data.frame(cbind(dat[1:2],dat[4], dat[71]))
which(colnames(dat)=="urbanRural" ) #71
new_dat_2 <- left_join(new_dat,subset_newdat2, by= c("Location.Id", "Id..Review.","User.Id"))
#new_dat_2 127257 obs 56 variables
sum(is.na(new_dat_2$urbanRural))
#0
####################################################################################
rm(dat2)
rm(LocData)
rm(NALoc_dat)
rm(NALP_dat)
rm(NAReviews_dat)
rm(new_dat_plus)
new_dat$check <- NULL
##############Creating a subset to be able to work with#############################
#Location.ID
which(colnames(new_dat_2)=="Location.Id" ) #1

#ConnectorsSite
which(colnames(new_dat_2)=="Connectors_site" ) #3

#Network_site
which(colnames(new_dat_2)=="Networks_site" ) #8

#Predicted Sentiment
which(colnames(new_dat_2)=="Predicted.Sentiment" )#10

#bestPOIGroup
which(colnames(new_dat_2)=="bestPOIGroup" )#14

#Dummy_PrivateNet
which(colnames(new_dat_2)=="Dummy_PrivateNet" )#54

#Urban Rural
which(colnames(new_dat_2)=="urbanRural" )#56

subset <- new_dat_2[c(1,3,8,10,14:54,56)]

which (colnames(new_dat_2)=="RYear" ) #19
subset$PredSent <- as.numeric(as.factor(subset$Predicted.Sentiment))
colnames(subset)[colnames(subset)=="TotalConnector"] <- "Total_Connectors"
subset$PP <- as.numeric(as.factor(subset$publicPrivate))

subset$Connectors_site <- as.character(subset$Connectors_site)

subset$Networks_site <- as.character(subset$Networks_site)
subset$Predicted.Sentiment <- as.character(subset$Predicted.Sentiment)
subset$bestPOIGroup <- as.character(subset$bestPOIGroup)
subset$publicPrivate <- as.character(subset$publicPrivate)
subset$DCFC <- as.numeric(subset$DCFC)
subset$J1772 <- as.numeric(subset$J1772)



#####Using a new data set#####
subset_AG <- as.data.frame(subset)

######################Creating Dummies###########################################
######DUMMY Predict sentiment ############################

subset_AG <- dummy_cols(subset_AG, select_columns = "Predicted.Sentiment")
colnames(subset_AG)[colnames(subset_AG)=="Predicted.Sentiment_NEGATIVE"] <- "Dummy_NEGATIVE"
colnames(subset_AG)[colnames(subset_AG)=="Predicted.Sentiment_POSITIVE"] <- "Dummy_POSITIVE"

#####DUMMY PUBLIC PRIVATE#####################################################################
subset_AG <- dummy_cols(subset_AG, select_columns = "publicPrivate")
colnames(subset_AG)[colnames(subset_AG)=="publicPrivate_Private"] <- "Dummy_PRIVATE"
colnames(subset_AG)[colnames(subset_AG)=="publicPrivate_Public"] <- "Dummy_PUBLIC"

#############Creating Count Negative Reviews Variable##################################
subset_AG$Review_Count_Negatives <-  (subset_AG$RC)*(subset_AG$Dummy_NEGATIVE)
sum(subset_AG$Review_Count_Negatives)
#58381
sum(is.na(subset_AG$Review_Count_Negatives))
#0

##################FIRST OPTION - AGGREGATING BY ID LOCATION INSTEAD OF POI################  
####Computing 1st stage variable###########################################################
model_1st <- aggregate(RC ~ RYear + Location.Id + PP, subset_AG, sum)
names(model_1st)[4]<-"Review_Count_SUMbyID"
subset_AG_model1 <- left_join(subset_AG,model_1st, by= c("Location.Id", "RYear","PP"))
#write.csv(subset_AG_model1, file = "subset_AG_model1.csv")
subset_AG_model1$Review_Rate <- subset_AG_model1$RC/subset_AG_model1$Total_RC_byID

#Location ID 100, 2012 = 11 RC
#PP = 11
#Review Count by ID = 11 
#Total RC by ID (includes the non observed - no review description but left a review)


#subset_AG$Review_Count_Negatives
model_2nd <- aggregate(Review_Count_Negatives ~ RYear + Location.Id + PP, subset_AG, sum)
names(model_2nd)[4]<-"NEG_SUMbyID"
subset_AG_ModelF_1 <- left_join(subset_AG_model1,model_2nd, by= c("Location.Id", "RYear","PP"))
#write.csv(subset_AG_ModelF_1, file = "subset_AG_ModelF_1 .csv")
subset_AG_ModelF_1$Neg_Score <- subset_AG_ModelF_1$NEG_SUMbyID/subset_AG_ModelF_1$Review_Count_SUMbyID

#Review count sum by id only includes observed 
#Creating Dummies for POI###########

#######################FINAL DATA SET##################################################
#subset_AG_ModelF_1 BY ID
VF_DATA <- as.data.frame(subset_AG_ModelF_1)
VF_DATA <- dummy_cols(VF_DATA, select_columns =  "bestPOIGroup")

colnames(VF_DATA)[colnames(VF_DATA)=="Review_Count_SUMbyID"] <- "RC_observed"
colnames(VF_DATA)[colnames(VF_DATA)=="Total_RC_byID"] <- "RC_obs_nobserved"

#write.csv(VF_DATA, file = "VF_DATA .csv")

summary(VF_DATA$Review_Rate)
#Min.  1st Qu.   Median     Mean  3rd Qu.     Max. 
#0.002392 0.016667 0.050000 0.144464 0.166667 1.000000

summary(VF_DATA$Neg_Score)
#Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#0.0000  0.2727  0.4928  0.4588  0.6429  1.0000
#######################FINAL DATA SET###########################################################
#Cleaning Global Enviroment
rm(subset)
rm(subset_AG_model1)
rm(temp)
rm(temp_count_byID)
rm(subset_AG)
rm(subset_AG_ModelF_1)
rm(model_1st)
rm(model_2nd)
rm(subset_temp_NAReviews)
#################################################################################################
#################################################################################################
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Car Dealership"] <- "bestPOIGroup_Car_Dealership"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Car Rental"] <- "bestPOIGroup_Car_Rental"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Convenience Store/Gas Station"] <- "bestPOIGroup_Convenience_Gas_Station"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Parking Garage/Lot"] <- "bestPOIGroup_Parking_Garage_Lot"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Place of Worship"] <- "bestPOIGroup_Place_Worship"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_RV Park"] <- "bestPOIGroup_RV_Park"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Shopping Center"] <- "bestPOIGroup_Shopping_Center"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Street Parking"] <- "bestPOIGroup_Street_Parking"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Transit Station"] <- "bestPOIGroup_Transit_Station"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Visitor Center"] <- "bestPOIGroup_Visitor_Center"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Hotel/Lodging"] <- "bestPOIGroup_Hotel_Lodging"
colnames(VF_DATA)[colnames(VF_DATA)=="bestPOIGroup_Restaurant/Food"] <- "bestPOIGroup_Restaurant_Food"
VF_DATA$bestPOIGroup_services <- NULL

###############################################################################################
###############################################################################################
VF_DATA$bestPOIGroup_Airport <- as.numeric(VF_DATA$bestPOIGroup_Airport)
VF_DATA$bestPOIGroup_Car_Dealership <- as.numeric(VF_DATA$bestPOIGroup_Car_Dealership)
VF_DATA$bestPOIGroup_Car_Rental <- as.numeric(VF_DATA$bestPOIGroup_Car_Rental)
VF_DATA$bestPOIGroup_Convenience_Gas_Station <- as.numeric(VF_DATA$bestPOIGroup_Convenience_Gas_Station)
VF_DATA$bestPOIGroup_Education <- as.numeric(VF_DATA$bestPOIGroup_Education)
VF_DATA$bestPOIGroup_Entertainment <- as.numeric(VF_DATA$bestPOIGroup_Entertainment)
VF_DATA$bestPOIGroup_Government <- as.numeric(VF_DATA$bestPOIGroup_Government)
VF_DATA$bestPOIGroup_Hotel_Lodging <- as.numeric(VF_DATA$bestPOIGroup_Hotel_Lodging)
VF_DATA$bestPOIGroup_Healthcare <- as.numeric(VF_DATA$bestPOIGroup_Healthcare)
VF_DATA$bestPOIGroup_Library <- as.numeric(VF_DATA$bestPOIGroup_Library)
VF_DATA$bestPOIGroup_Other <- as.numeric(VF_DATA$bestPOIGroup_Other)
VF_DATA$bestPOIGroup_Outdoor <- as.numeric(VF_DATA$bestPOIGroup_Outdoor)
VF_DATA$bestPOIGroup_Parking_Garage_Lot <- as.numeric(VF_DATA$bestPOIGroup_Parking_Garage_Lot)
VF_DATA$bestPOIGroup_Place_Worship <- as.numeric(VF_DATA$bestPOIGroup_Place_Worship)
VF_DATA$bestPOIGroup_Residential <- as.numeric(VF_DATA$bestPOIGroup_Residential)
VF_DATA$bestPOIGroup_Restaurant_Food <- as.numeric(VF_DATA$bestPOIGroup_Restaurant_Food)
VF_DATA$bestPOIGroup_RV_Park <- as.numeric(VF_DATA$bestPOIGroup_RV_Park)
VF_DATA$bestPOIGroup_Services <- as.numeric(VF_DATA$bestPOIGroup_Services)
VF_DATA$bestPOIGroup_Shopping <- as.numeric(VF_DATA$bestPOIGroup_Shopping)
VF_DATA$bestPOIGroup_Shopping_Center <- as.numeric(VF_DATA$bestPOIGroup_Shopping_Center)
VF_DATA$bestPOIGroup_Street_Parking <- as.numeric(VF_DATA$bestPOIGroup_Street_Parking)
VF_DATA$bestPOIGroup_Supermarket <- as.numeric(VF_DATA$bestPOIGroup_Supermarket)
VF_DATA$bestPOIGroup_Transit_Station <- as.numeric(VF_DATA$bestPOIGroup_Transit_Station)
VF_DATA$bestPOIGroup_Unknown <- as.numeric(VF_DATA$bestPOIGroup_Unknown)
VF_DATA$bestPOIGroup_Visitor_Center <- as.numeric(VF_DATA$bestPOIGroup_Visitor_Center)
VF_DATA$bestPOIGroup_Workplace <- as.numeric(VF_DATA$bestPOIGroup_Workplace)
###############################################################################################
###############################################################################################
vf <- as.data.frame(VF_DATA)
vf <- vf[!is.na(vf$PlugScore),]
###############################################################################################
###############################################################################################
sum(is.na(vf$bestPOIGroup_Services))
summary(vf$bestPOIGroup_services)
summary(vf$bestPOIGroup_Services)


##################################################################################################
library(lattice)
histogram( ~ Review_Rate | bestPOIGroup , data=VF_DATA, 
           layout=c(3,9) , scales= list(y=list(relation="free"),
                                        x=list(relation="free") ) )

histogram( ~ Neg_Score | bestPOIGroup , data=VF_DATA, 
           layout=c(3,9) , scales= list(y=list(relation="free"),
                                        x=list(relation="free") ) )


###############
library(dplyr)
d <- VF_DATA %>% 
  group_by(bestPOIGroup) %>%
  summarise(no_rows = length(bestPOIGroup))

sum(d$no_rows)

################
#install.packages("fitdistrplus")
#install.packages("logspline")
library(fitdistrplus)
library(logspline)

############# REVIEW RATE DISTRIBUTION
##BY ID
hist(VF_DATA$Review_Rate, main = "Model by ID : Review Rate")
p <- density(VF_DATA$Review_Rate) # returns the density data 
plot(p, main = "Model by ID : Review Rate")
#descdist(subset_AG_ModelF_1$Review_Rate, discrete = FALSE)
#fit.gammaMR <- fitdist(ssubset_AG_ModelF_1$Review_Rate, "gamma")
#plot(fit.gammaMR, main = "Model by ID : Review Rate")

hist(VF_DATA$Neg_Score, main = "Model by ID : Negativity Score")
d <- density(VF_DATA$Neg_Score) # returns the density data 
plot(d, main = "Model by ID : Negativity Score")
#descdist(subset_AG_ModelF_1$Neg_Score, discrete = FALSE)
#fit.gammaRR <- fitdist(subset_AG_ModelF_1$Neg_Score, "gamma")
#plot(fit.gammaRR)

rm(d) 
rm(p)

####################################################################################
####################################################################################
#Approach Paper Wooldridge 
#The differences in the two approaches (FRM and GLM) stem from 
#different degree of freedom corrections in the 
#computation of the robust standard errors. 
#Using similar defaults, the results will be identical.
#Note that frm is for fractional and thus numeric values and not for categorical variables.
##############################################################################
##############################################################################
##############################################################################
#############################################################################
#############'Creating a variable for Cluster Networks and Cluster Connectors'#####
###Connectors gather##########
VF_DATA$TeslaSuper_count <- VF_DATA$Dummy_TeslaSupercharger
VF_DATA$WALL_count <- ifelse(VF_DATA$Dummy_WallOutlet == 1,2,0)
VF_DATA$CCS_count <- ifelse(VF_DATA$Dummy_CCS_SAECombo == 1 , 3 ,0)
VF_DATA$J1772_count <- ifelse (VF_DATA$Dummy_J_1772 == 1 , 4, 0)
VF_DATA$TESLARod_count  <- ifelse(VF_DATA$Dummy_TeslaRoadster ==1, 5 , 0)
VF_DATA$NEMA_count <- ifelse(VF_DATA$Dummy_NEMA_Plug_240v == 1, 6, 0)
VF_DATA$TESLAS_count <- ifelse(VF_DATA$Dummy_TeslaModel_S == 1, 7, 0)

VF_DATA$gather <- paste(VF_DATA$TeslaSuper_count,",",VF_DATA$WALL_count,",",VF_DATA$CCS_count,",",VF_DATA$J1772_count,
                        ",",VF_DATA$TESLARod_count,",",
                        VF_DATA$NEMA_count,",",VF_DATA$TESLAS_count)

VF_DATA$gather <- as.factor(VF_DATA$gather)
VF_DATA$gather <-gsub(",","",VF_DATA$gather) # removing ,
VF_DATA$gather <-gsub("0","",VF_DATA$gather) # removing 0's
VF_DATA$gather <-  gsub("\\s", "", VF_DATA$gather) 
VF_DATA$gather_connectors <- VF_DATA$gather
VF_DATA$TeslaSuper_count <- NULL
VF_DATA$WALL_count<- NULL
VF_DATA$CCS_count <- NULL
VF_DATA$J1772_count<- NULL
VF_DATA$TESLARod_count <- NULL
VF_DATA$NEMA_count <- NULL
VF_DATA$TESLAS_count <- NULL
VF_DATA$gather <- NULL
unique(factor(VF_DATA$gather_connectors))
#NOW 35 levels
unique(factor(VF_DATA$Connectors_site))
#BEFORE 50 LEVELS
sum(is.na(VF_DATA$gather_connectors))
#0
VF_DATA$gather_connectors <- as.factor(VF_DATA$gather_connectors)

##Conectors gather NETWORK############################################################
VF_DATA$ChargeP_count <- ifelse(VF_DATA$Dummy_ChargePoint==1,1,"")
VF_DATA$Carcharg_count <- ifelse(VF_DATA$Dummy_CarCharging == 1,2,"")
VF_DATA$Blink_count <- ifelse(VF_DATA$Dummy_Blink == 1 , 3 ,"")
VF_DATA$GEWatt_count <- ifelse (VF_DATA$Dummy_GEWattStation == 1 , 4, "")
VF_DATA$EVgo_count  <- ifelse(VF_DATA$Dummy_EVgo ==1, 5 , "")
VF_DATA$Greenlots_count <- ifelse(VF_DATA$Dummy_Greenlots == 1, 6, "")
VF_DATA$Shorepower_count <- ifelse(VF_DATA$Dummy_Shorepower == 1, 7, "")
VF_DATA$Aero_count <- ifelse(VF_DATA$Dummy_AeroVironment == 1, 8, "")
VF_DATA$SEMA_count<- ifelse(VF_DATA$Dummy_SemaCharge == 1, 9, "")
VF_DATA$NetSu_count<- ifelse(VF_DATA$Dummy_NetSuperCharger == 1, 10, "")
VF_DATA$JNSH_count<- ifelse(VF_DATA$Dummy_JNSH == 1, 11, "")
VF_DATA$Dest_count<- ifelse(VF_DATA$Dummy_Destination == 1, 12, "")
VF_DATA$Volta_count<- ifelse(VF_DATA$Dummy_Volta == 1, 13, "")
VF_DATA$RAc_count<- ifelse(VF_DATA$Dummy_RechargeAccess == 1, 14, "")
VF_DATA$Sun_count<- ifelse(VF_DATA$Dummy_SunCountry == 1, 15, "")
VF_DATA$DOA_count<- ifelse(VF_DATA$Dummy_DOEAFDC == 1, 16, "")
VF_DATA$RWE_count<- ifelse(VF_DATA$Dummy_RWE == 1, 17, "")
VF_DATA$Opcon_count<- ifelse(VF_DATA$Dummy_OpConnect == 1, 18, "")
VF_DATA$PrivNet_count<- ifelse(VF_DATA$Dummy_PrivateNet == 1, 19, "")

VF_DATA$gathern <- paste(
  VF_DATA$ChargeP_count ,",",
  VF_DATA$Carcharg_count ,",",
  VF_DATA$Blink_count ,",",
  VF_DATA$GEWatt_count ,",",
  VF_DATA$EVgo_count ,",",
  VF_DATA$Greenlots_count ,",",
  VF_DATA$Shorepower_count ,",",
  VF_DATA$Aero_count ,",",
  VF_DATA$SEMA_count,",",
  VF_DATA$NetSu_count,",",
  VF_DATA$JNSH_count,",",
  VF_DATA$Dest_count,",",
  VF_DATA$Volta_count,",",
  VF_DATA$RAc_count,",",
  VF_DATA$Sun_count,",",
  VF_DATA$DOA_count,",",
  VF_DATA$RWE_count,",",
  VF_DATA$Opcon_count,",",
  VF_DATA$PrivNet_count
  
  
)


VF_DATA$gathern <-gsub(",","",VF_DATA$gathern) # removing ,
VF_DATA$gathern <-  gsub("\\s", "", VF_DATA$gathern) 
VF_DATA$gather_networks <- VF_DATA$gathern


VF_DATA$gathern <- as.factor(VF_DATA$gathern)

#NOW 42 LEVELS
unique(factor(VF_DATA$gather_networks))

#BEFORE 48 LEVELS
unique(factor(VF_DATA$Networks_site))

VF_DATA$gathern <- NULL
VF_DATA$ChargeP_count <- NULL
VF_DATA$Carcharg_count <- NULL
VF_DATA$Blink_count <- NULL
VF_DATA$GEWatt_count <- NULL
VF_DATA$EVgo_count  <- NULL
VF_DATA$Greenlots_count <- NULL
VF_DATA$Shorepower_count <- NULL
VF_DATA$Aero_count <- NULL
VF_DATA$SEMA_count <- NULL
VF_DATA$NetSu_count<- NULL
VF_DATA$JNSH_count<- NULL
VF_DATA$Dest_count<- NULL
VF_DATA$Volta_count <- NULL
VF_DATA$RAc_count<- NULL
VF_DATA$Sun_count<- NULL
VF_DATA$DOA_count<- NULL
VF_DATA$RWE_count<- NULL
VF_DATA$Opcon_count<- NULL
VF_DATA$PrivNet_count<- NULL


#setwd("C:/Users/CATHARINA/Documents/Gatech/2018.2/Paper/Paper/Summary - Paper")
#write.csv(VF_DATA, file = "VF_DATA_withNAs .csv")
#setwd("C:/Users/CATHARINA/Documents/Gatech/2018.2/Paper/Paper")
#################################################################################################
################Creating another data set and inserting plug score levels variable##############################################################
#PlugScore NAs as zeros
VF_DATA_PScore_NAs <- as.data.frame(VF_DATA)
VF_DATA_PScore_NAs$PlugScore[is.na(VF_DATA_PScore_NAs$PlugScore)] <- 0

#Include Plug Score Levels for first and second stage
#Treat 0 = PlugScore
#Very Poor = 1.0 - 5.0
#Poor = 5.0 - 7.0
#Fair = 7.0 - 9.0
#Excellent = 9.0 - 10.0

#Changed the labels

VF_DATA_PScore_NAs$PlugScore_Levels <- NA
VF_DATA_PScore_NAs$PlugScore_Levels <-cut(VF_DATA_PScore_NAs$PlugScore, c(0,1,5,7,9,11), right=FALSE, labels = c("No PlugScore","Very Poor", "Poor", "Fair", "Excellent"))
#write.csv(VF_DATA_PScore_NAs, "VF_DATA_PScore_NAs.csv")


##############################Creating Data sets#########################################################
###Creating a data set with plug level####
Data_1st <- as.data.frame(VF_DATA_PScore_NAs)
sum(is.na(Data_1st$PlugScore_Levels))
Data_1st$Plug <- NA
Data_1st$Plug <- Data_1st$PlugScore_Levels
unique(factor(Data_1st$PlugScore_Levels))

levels(Data_1st$Plug) <- 0:4
unique(factor(Data_1st$Plug))

Data_1st$Plug <- as.numeric(Data_1st$Plug)


###Creating data set with trimmed obs because of Plug Score that has NAs#####
vf <- as.data.frame(VF_DATA)
vf <- vf[!is.na(vf$PlugScore),]
Data_1st_trim <- as.data.frame(vf)


###################################################Creating Dummies for UrbanRural##########
#0 Rural
#1 Urban Cluster 1
#2 Urban center

Data_1st_new <-  dummy_cols(Data_1st, select_columns = "urbanRural")
colnames(Data_1st_new)[colnames(Data_1st_new)=="urbanRural_2"] <- "DUrban_Center"
colnames(Data_1st_new)[colnames(Data_1st_new)=="urbanRural_1"] <- "DUrban_Cluster"
colnames(Data_1st_new)[colnames(Data_1st_new)=="urbanRural_0"] <- "DRural"

#Verifying counts for urbanRural variable 
# sum(Data_1st_new$urbanRural == "2")
#[1] 112693
# sum(Data_1st_new$urbanRural == "1")
#[1] 7310
# sum(Data_1st_new$urbanRural == "0")
#[1] 7254


