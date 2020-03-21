# Imports
# Set seeds for python, numpy and tensorflow for reproducibility
from numpy.random import seed
seed(1)
from tensorflow import set_random_seed
set_random_seed(1)
import os
os.environ['PYTHONHASHSEED'] = '0'
import random as rn
rn.seed(1)
import tensorflow as tf
from keras import backend as K
# Force tensorflow to use a single thread (recommended for reproducibility)
session_conf = tf.ConfigProto(intra_op_parallelism_threads=1, inter_op_parallelism_threads=1)
sess = tf.Session(graph=tf.get_default_graph(), config=session_conf)
K.set_session(sess)
import keras
from keras.constraints import max_norm
from keras.layers import Conv2D, MaxPooling2D, Reshape, Conv1D, MaxPooling1D, Concatenate, RNN
import gensim
from time import time
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from keras.models import Model, Sequential, load_model
from keras.layers import Input, Embedding, Dense, Dropout, Bidirectional, TimeDistributed, Flatten
from keras import optimizers
from keras.preprocessing.text import Tokenizer
from keras.preprocessing.sequence import pad_sequences
from sklearn.metrics import accuracy_score
from sklearn.metrics import precision_score
from sklearn.metrics import recall_score
from sklearn.metrics import cohen_kappa_score
from keras.layers.recurrent import LSTM
from keras.callbacks import EarlyStopping, ModelCheckpoint




# Removes punctuation from input text
def clean_text(text):
    exclude = set(['.', ',', '?', '!'])
    text = ''.join(ch for ch in text if ch not in exclude)
    return text

# Creates the CNN with the specified parameters

# Train CNN model and evaluate performance.
def main():

    # Create embedding matrix
    # Size of the dimensionality of the pre-trained word embeddings
    embedding_size = 300
    print('Loading pre-trained word embeddings..')
    file_name = 'GoogleNews-vectors-negative300.bin.gz'
    w2v = gensim.models.KeyedVectors.load_word2vec_format(file_name, binary=True)
    print('creating embedding matrix..')
    
    # Read in training data
    df = pd.read_csv('training_data.csv')
    #df= df.sample(frac=0.1)

    # Clean review text
    df['Review'] = df['Review'].apply(clean_text)
    df['Review'] = df['Review'].str.lower()

    # Captitalize sentiment
    df['Sentiment'] = df['Sentiment'].str.upper()

    # Map class names to numbers
    binary_rating_mapping = {'NEGATIVE': 0.0,
                             'POSITIVE': 1.0}
    df['Sentiment'] = df['Sentiment'].map(binary_rating_mapping)
        
    # Split data into train and test set
    reviews_train, reviews_test, \
    y_train, y_test = train_test_split(df['Review'].values,
                                       df['Sentiment'].values,
                                       test_size=0.2,
                                       random_state = 22)
    print('Train size: %s' % len(reviews_train))
    print('Test size: %s' % len(reviews_test))

    # Convert numpy arrays to lists
    reviews_train = list(reviews_train)
    reviews_test = list(reviews_test)
    y_train = list(y_train)
    y_test = list(y_test)

    # Tell the tokenizer to use the entire vocabulary
    num_words = None
    tokenizer = Tokenizer(num_words=num_words, oov_token='Out_Of_Vocab_Token')
    tokenizer.fit_on_texts(reviews_train)

    # Now set number of words to the size of the vocabulary
    num_words = len(tokenizer.word_index)

    # Convert reviews to lists of tokens
    x_train_tokens = tokenizer.texts_to_sequences(reviews_train)
    x_test_tokens = tokenizer.texts_to_sequences(reviews_test)

    # Pad all sequences of tokens to be the same length (length of the longest sequence)
    num_tokens = [len(tokens) for tokens in x_train_tokens]
    num_tokens = np.array(num_tokens)
    max_tokens = np.max(num_tokens)

    # Pad zeroes to the beginning of the sequences
    pad = 'pre'
    x_train_pad = pad_sequences(x_train_tokens, maxlen=max_tokens, padding=pad, truncating=pad)
    x_test_pad = pad_sequences(x_test_tokens, maxlen=max_tokens, padding=pad, truncating=pad)



    # Good explaination of this at https://blog.keras.io/using-pre-trained-word-embeddings-in-a-keras-model.html
    num_missing = 0
    # indices of rows in embedding matrix that aren't initialized (because the corresponding word was not in word2vec)
    missing_word_indices = []
    embedding_matrix = np.zeros((num_words + 1, embedding_size))
    for word, i in tokenizer.word_index.items():
        if word in w2v.vocab:
            embedding_vector = w2v[word]
            embedding_matrix[i] = embedding_vector
        else:
            num_missing += 1
            missing_word_indices.append(i)

    # Fill in uninitialized rows of embedding matrix with random numbers. 0.25 is chosen so these vectors
    # have approximately the same variance as the pre-trained word2vec ones
    random_vectors = np.random.uniform(-0.25, 0.25, (num_missing, embedding_size))
    for i in range(num_missing):
        embedding_matrix[missing_word_indices[i]] = random_vectors[i]



    # Build model
    text_input = Input(shape=(max_tokens,), dtype='int32', name='text_input')

    # Embedding layer
    embeddings = Embedding(input_dim=num_words + 1, output_dim=embedding_size,
                           weights=[embedding_matrix], trainable=True,
                           input_length=max_tokens, name='embedding_layer')(text_input)
    
    lstm = LSTM(64, dropout=0.6, recurrent_dropout=0.2)(embeddings)
    
    output = Dense(1, activation='sigmoid')(lstm)
    
    model = Model(inputs = text_input, outputs = output)
    
    
    # try using different optimizers and different optimizer configs
    model.compile(loss='binary_crossentropy',
                  optimizer='adam',
                  metrics=['accuracy'])
    
    print('Train...')
    
    
    filepath="rnnmodel.hdf5"
    checkpoint = ModelCheckpoint(filepath, monitor='val_acc', verbose=1, save_best_only=True, mode='max')
    callbacks_list = [checkpoint]
    t0 = time()

    history = model.fit(x_train_pad, y_train,
              batch_size=128,
              epochs=8,
              callbacks = callbacks_list)
    duration = time() - t0
    
    model.save(filepath)
    
    
    #model = load_model(filepath)


    # Generate predictions on test set
    
    
    print("done in %fs" % (duration))
    print('Generating predictions on the test set...\n')
    
    t0 = time()
    
    y_pred = model.predict(x_test_pad)
    
    prediction_time = time() - t0

    y_pred_class = np.round(y_pred, 0)
    

    
    
    accuracy = 100 * accuracy_score(y_test, y_pred_class)
    precision = precision_score(y_test, y_pred_class)
    recall = recall_score(y_test, y_pred_class)
    f1_score = 2*precision*recall/(precision+recall)
    
    # Evaluate model performance
    print('Accuracy: %.2f%%' % accuracy)
    print('Precision: %.2f' % precision)
    print('Recall: %.2f' % recall)
    print('F1 Score: %.2f' % f1_score)
    print('Training Time: %f' % duration)
    print('Prediction Time: %f' % prediction_time)    
    
    
    result = pd.DataFrame({'Accuracy':[accuracy],'Precision':[precision], 'Recall': [recall], 'F1 Score': [f1_score], 'Training Time': [duration], 'Prediction Time': [prediction_time]})

    result.to_csv('rnn_test.csv', index=True, mode=  'a', header=False)

     



if __name__ == '__main__':
    main()
