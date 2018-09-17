import pandas as pd

# Create final predictions dataset by replacing machine predictions of reviews that are in training set with
# ground truth labels from humans
def main():
    # Machine predictions for entire dataset
    predictions = pd.read_csv('NA Reviews Data Sentiment.csv')

    # Training data with ground truth labels
    training = pd.read_csv('training_data.csv')

    # Only keep needed columns from training data
    training = training[['Id (Review)', 'Sentiment']]

    # Join datasets
    joined = predictions.join(training.set_index('Id (Review)'), on='Id (Review)')

    # Capitalize training labels to match format of prediction labels
    joined['Sentiment'] = joined['Sentiment'].str.upper()

    # Make new column that uses the training label when available, and the machine prediction otherwise
    joined['Best Sentiment'] = joined['Predicted Sentiment']

    joined.loc[(joined['Predicted Sentiment'] != joined['Sentiment'])
               & (pd.notnull(joined['Sentiment'])) &
               (joined['Predicted Sentiment'] == 'POSITIVE'), 'Best Sentiment'] = 'NEGATIVE'

    joined.loc[(joined['Predicted Sentiment'] != joined['Sentiment'])
               & (pd.notnull(joined['Sentiment'])) &
               (joined['Predicted Sentiment'] == 'NEGATIVE'), 'Best Sentiment'] = 'POSITIVE'

    # Only include needed columns
    joined = joined[['Id (Review)', 'User Id', 'name (vehicle)', 'Location Id', 'Created At (Review)',
                     'Connectors_site', 'Networks_site', 'Check-in Rating (alias)', 'Review', 'Best Sentiment']]

    joined = joined.rename(columns={'Best Sentiment': 'Predicted Sentiment'})

    joined.to_csv('NA Reviews Data Best Sentiment.csv', index=False)

if __name__ == '__main__':
    main()