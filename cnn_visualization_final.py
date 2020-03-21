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
from keras.layers import Conv2D, MaxPooling2D, Reshape, Conv1D, MaxPooling1D, Concatenate
import gensim
from time import time
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from keras.models import Model, load_model
from keras.layers import Input, Embedding, Dense, Dropout
from keras import optimizers
from keras.preprocessing.text import Tokenizer
from keras.preprocessing.sequence import pad_sequences
from sklearn.metrics import accuracy_score
from sklearn.metrics import precision_score
from sklearn.metrics import recall_score
from sklearn.metrics import cohen_kappa_score
from keras.callbacks import ModelCheckpoint
import matplotlib.pyplot as plt


# Removes punctuation from input text
def clean_text(text):
    exclude = set(['.', ',', '?', '!'])
    text = ''.join(ch for ch in text if ch not in exclude)
    return text

# Creates the CNN with the specified parameters
def create_model(embedding_matrix, num_words, max_tokens, filter_sizes,
                 lr=1e-3, l2_constraint=None, num_filters=100,
                 dropout_percent=0.3, embedding_size=300):
    """
    Creates the CNN with the specified parameters.

    Parameters
    ----------
    embedding_matrix: array, shape (num_words + 1, embedding_size)
        Matrix to use to initialize the weights in the embedding layer

    num_words: int
        Number of words in the vocabulary

    max_tokens: int
        Number of tokens for each input review. This is the number of tokens in the
        largest review in the training set. All other inputs are padded with 0s to
        have this number of tokens.

    filter_sizes: list
        The heights of the filters in the convoutional layer. There will be an equal
        number of filters per filter size

    lr: double, optional, default 0.001
        Learning rate. It controls the step-size in updating the weights

    l2_constraint: optional, default None
        If the L2-norm of the weights in the dense layer exceed this number, scale the
        weight matrix by a factor that reduces the norm to this number.

    num_filters: int, optional, default 100
        Number of filters per filter size in filter_sizes

    dropout_percent: float, optional, default 0.5
        Dropout rate for regularization

    embedding_size: int, optional, default 300
        Dimensionality of word embeddings

    """

    # text input (reviews)
    text_input = Input(shape=(max_tokens,), dtype='int32', name='text_input')

    # Embedding layer
    embeddings = Embedding(input_dim=num_words + 1, output_dim=embedding_size,
                           weights=[embedding_matrix], trainable=True,
                           input_length=max_tokens, name='embedding_layer')(text_input)

    # Reshape embedding tensor to match expected dimensions of conv2D
    #embeddings_expanded = Reshape((max_tokens, embedding_size, 1))(embeddings)


    pooling_outputs = []
    # Convolution layers
    for i, filter_size in enumerate(filter_sizes):
        conv = Conv1D(filters=num_filters, kernel_size=[filter_size], strides=1,
                      padding='valid', name='conv' + str(i), activation='relu')(embeddings)
        pool_size = tuple([max_tokens - filter_size + 1])
        pooled = MaxPooling1D(strides=1, pool_size=(pool_size),
                              padding='valid', name='pool' + str(i))(conv)
        pooling_outputs.append(pooled)

    x = Concatenate(pooling_outputs)

    # Reshape the pooled output to one long feature vector
    #x = Reshape((num_filters * len(filter_sizes),))(x)

    # dropout to prevent overfitting
    x = Dropout(rate=dropout_percent)(x)

    # Create dense layer for binary classification (will output value between 0 and 1)
    output = Dense(1, activation='sigmoid')(x)

    # Create model with the above architecture
    model = Model(inputs=text_input, outputs=output)

    # Use Adam optimizer
    optimizer = optimizers.Adam(lr=lr)

    # Compile the model
    model.compile(optimizer=optimizer, loss='binary_crossentropy', metrics=['accuracy'])
    return model

# Train CNN model and evaluate performance.
def main():
    # Read in training data
    df = pd.read_csv('training_data.csv')

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
                                       random_state=22)
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

    # Create embedding matrix
    # Size of the dimensionality of the pre-trained word embeddings
    embedding_size = 300
    print('Loading pre-trained word embeddings..')
    t0 = time()
    file_name = 'GoogleNews-vectors-negative300.bin.gz'
    w2v = gensim.models.KeyedVectors.load_word2vec_format(file_name, binary=True)
    duration = time() - t0
    print("done in %fs" % (duration))
    print('creating embedding matrix..')

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

    t0 = time()
    duration = time() - t0
    print("done in %fs" % (duration))

    # Build model
    model = create_model(embedding_matrix=embedding_matrix, num_words=num_words, max_tokens=max_tokens,
                         filter_sizes=[3, 4, 5], l2_constraint=None,
                         dropout_percent=0.3)
    
    filepath="dropout03viz.hdf5"
    checkpoint = ModelCheckpoint(filepath, monitor='val_acc', verbose=1, save_best_only=True, mode='max')
    callbacks_list = [checkpoint]
    

    # Train model
    history = model.fit(x_train_pad, y_train, epochs=3, batch_size=128,callbacks = callbacks_list)

    # Generate predictions on test set
    print('Generating predictions on the test set...\n')
    y_pred = model.predict(x_test_pad)
    y_pred_class = np.round(y_pred, 0)

    # Evaluate model performance
    print('Accuracy: %.2f%%' % (100 * accuracy_score(y_test, y_pred_class)))
    print('Precision: %.2f' % precision_score(y_test, y_pred_class))
    print('Recall: %.2f' % recall_score(y_test, y_pred_class))

    index_to_word = dict((v,k) for k, v in tokenizer.word_index.items())        
    
    
    get_region_embedding_a = K.function([model.layers[0].input,K.learning_phase()],
                                    [model.layers[3].output])

    get_region_embedding_b = K.function([model.layers[0].input,K.learning_phase()],
                                        [model.layers[4].output])
    
    get_region_embedding_c = K.function([model.layers[0].input,K.learning_phase()],
                                        [model.layers[5].output])    
    
    get_softmax = K.function([model.layers[0].input,K.learning_phase()],
                             [model.layers[12].output])   
    

    n_doc_per_label = 50
    # Predicted y label
    idx_pos = [idx for idx,elt in enumerate(y_test) if elt==1]
    idx_neg = [idx for idx,elt in enumerate(y_test) if elt==0]
    #my_idxs = idx_pos 
    #my_idxs = idx_neg
    my_idxs =  idx_neg[:n_doc_per_label] + idx_pos[:n_doc_per_label] 
    my_idxs = [40, 187]
    #my_idxs = [1]
    
    #my_idxs =  idx_neg[251:300] + idx_pos[251:300] 

    
    x_test_pad2 = pad_sequences(x_test_tokens, maxlen=max_tokens, padding='post', truncating='post')
    
    
    # True y label
    x_test_my_idxs = np.array([x_test_pad2[elt] for elt in my_idxs])
    y_test_my_idxs = [y_test[elt] for elt in my_idxs]
    
    reg_emb_a = get_region_embedding_a([x_test_my_idxs,0])[0]
    reg_emb_b = get_region_embedding_b([x_test_my_idxs,0])[0]
    reg_emb_c = get_region_embedding_c([x_test_my_idxs,0])[0]
    

    
    # predictions are probabilities of belonging to class 1
    # note: you can also use directly: 
    predictions = model.predict(x_test_pad[:100]).tolist()
        
    input_tensors = [model.input, K.learning_phase()]
    saliency_input = model.layers[1].output # before split into branches
    saliency_output = model.layers[12].output # class score
    gradients = model.optimizer.get_gradients(saliency_output,saliency_input)
    compute_gradients = K.function(inputs=input_tensors,outputs=gradients)
     
    saliency_path = 'C:\\Users\\Susie\\Documents\\GitHub\\popular-sentiment-electric-vehicle-drivers-united-states\\saliency_figures0814\\'
    
    

    for idx,doc in enumerate(x_test_my_idxs):
        matrix = compute_gradients([np.array([doc]),0])[0][0,:,:]
        tokens = [index_to_word[elt] for elt in doc if elt!=0]
        to_plot = np.absolute(matrix[:len(tokens),:])
        #to_plot = to_plot.reshape(len(tokens),300)
        fig, ax = plt.subplots()
        heatmap = ax.imshow(to_plot, cmap=plt.cm.BuPu,interpolation='nearest',aspect='auto')
        ax.set_yticks(np.arange(len(tokens)))
        #cb = plt.colorbar()
        #cb.set_label(label = 'Saliency Score', labelsize = 12)
        ax.set_yticklabels(tokens)
        ax.tick_params(axis='y', which='major', labelsize=20)
        fig.colorbar(heatmap)
        fig.set_size_inches(14,9)
        fig.savefig(saliency_path+str(idx)+'0902.pdf',bbox_inches='tight')
        fig.show()        
    


if __name__ == '__main__':
    main()
