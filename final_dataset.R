library(readr)
library(dplyr)

#dataset with predictions for each review
reviews_sentiment <- read_csv("NA Reviews Data Best Sentiment.csv")

#dataset with census data for locations
locationwithcensus <- read_csv("NA_Location_Data_7-16-18.csv")

#adds country to census data, since some of the locations are in canada. If the state abbreviation is in the US, it gets a label of USA, else, it gets a label of Canada
locationwithcensus <- locationwithcensus %>%
  mutate(country = ifelse(state %in% c('AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'WV', 'VA', 'WA', 'WI', 'WY', 'DC'), 'USA', 'CAN')) %>%
  filter(country == 'USA')

#new dataset that joins the reviews, the predictions, the locations, and the census data
reviewlocation <- inner_join(reviews_sentiment, locationwithcensus, by = c(`Location Id` = 'id')) 

#this adds a designation of publicly and privately owned stations. We used points of interest to do this. For some categories (education, for example), we manually designated them as public/private because the category had a mix of publicly and privately owned stations. For the remainder, we sorted entire groups into one category. 
reviewlocation <- reviewlocation %>%
  mutate(publicPrivate = ifelse(!is.na(publicPrivate), publicPrivate,
                                ifelse(bestPOIGroup == 'Outdoor' | bestPOIGroup == 'Government' | bestPOIGroup == 'Library' | bestPOIGroup == 'Transit Station' | bestPOIGroup == 'Visitor Center / Rest Stop' | bestPOIGroup == 'Street Parking' | bestPOIGroup ==  'Airport', 'Public', 'Private')))

#removes redundant columns from the dataset
reviewlocation[ ,c('locationId', 'original missing', 'state', 'State', 'duplicates', 'fixPlease', 'Location Id.y', 'avgSent', 'bestPOI')] <- list(NULL)

#writes final dataset into csv
write_csv(reviewlocation, "final_data.csv")


#this dataset is the mean probability of negative sentiment and number of reviews at each location
locations_scores <- reviewlocation %>%
  filter(`Predicted Sentiment` == 'POSITIVE' | `Predicted Sentiment` == 'NEGATIVE') %>%
  mutate(sentiment_values = ifelse(`Predicted Sentiment` == 'POSITIVE', 1, 0)) %>%
  group_by(`Location Id`) %>%
  mutate(count = n()) %>%
  mutate(prob = 1-sum(sentiment_values)/n()) %>%
  distinct(`Location Id`, .keep_all = TRUE)

write_csv(locations_scores, "sentiment_location.csv")
