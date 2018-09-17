import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score
from sklearn.metrics import precision_score
from sklearn.metrics import recall_score

# Removes punctuation from input text
def clean_text(text):
    #text = str(text)
    exclude = set(['.', ',', '?', '!'])
    text = ''.join(ch for ch in text if ch not in exclude)
    return text


# Trains Logistic Regression model and evaluates performance
def main():
    df = pd.read_csv('training_data.csv')

    # Clean review text
    df['Review'] = df['Review'].apply(clean_text)
    df['Review'] = df['Review'].str.lower()

    # Captitalize sentiments
    df['Sentiment'] = df['Sentiment'].str.upper()

    # Map class names to numbers
    binary_rating_mapping = {'NEGATIVE': 0.0,
                             'POSITIVE': 1.0}
    df['Sentiment'] = df['Sentiment'].map(binary_rating_mapping)

    # Train test split
    reviews_train, reviews_test, \
    y_train, y_test = train_test_split(df['Review'], df['Sentiment'], test_size=0.2, random_state=22)

    # Create tf-idf matrix for train and test set
    tfidf_vectorizer = TfidfVectorizer(max_df=0.95, min_df=2, stop_words='english', ngram_range=(1, 3))
    X_train = tfidf_vectorizer.fit_transform(reviews_train)
    X_test = tfidf_vectorizer.transform(reviews_test)

    # Create Logistic Regression classifier
    clf = LogisticRegression(random_state=1, C=2.5)

    # Train model
    clf.fit(X_train, y_train)

    # Create predictions on test set
    y_pred = clf.predict(X_test)

    # Evaluate model performance
    print('Accuracy: %.1f%%' % (100 * accuracy_score(y_test, y_pred)))
    print('Precision: %.2f' % precision_score(y_test, y_pred))
    print('Recall: %.2f' % recall_score(y_test, y_pred))


if __name__ == '__main__':
    main()
