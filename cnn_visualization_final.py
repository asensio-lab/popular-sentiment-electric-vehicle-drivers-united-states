import os
os.environ['PYTHONHASHSEED'] = '0'
import random as rn
rn.seed(1)
import tensorflow as tf
from keras import backend as K
session_conf = tf.ConfigProto(intra_op_parallelism_threads=1, inter_op_parallelism_threads=1)
sess = tf.Session(graph=tf.get_default_graph(), config=session_conf)
K.set_session(sess)
import numpy as np
from keras.preprocessing.sequence import pad_sequences
from keras.models import load_model
import matplotlib.pyplot as plt
import pickle


def main():

    review_text = ["6 reserved spots 4 iced","spot for charging iced by dealer car"]
    
    # Load tokenizer fitted on the training data
    with open('tokenizer.pickle', 'rb') as handle:
        tokenizer = pickle.load(handle)


    # Convert reviews to lists of tokens
    x_test_tokens = tokenizer.texts_to_sequences(review_text)

    # Pad all sequences of tokens to be the same length of the longest sequence in training data

    max_tokens = 538 # on the training data
    
    # Pad zeroes to the beginning of the sequences
    pad = 'pre'
    x_test_pad = pad_sequences(x_test_tokens, maxlen=max_tokens, padding=pad, truncating=pad)


    # Load trained CNN model
    filepath="cnn_model.hdf5"
    model = load_model(filepath)

    # Generate predictions on test reviews
    y_pred = model.predict(x_test_pad)    
    y_pred_class = np.round(y_pred, 0)

    # Bring vocabulary from tokenizer
    index_to_word = dict((v,k) for k, v in tokenizer.word_index.items())        
    
    # Pad test reviews for visualization
    x_test_pad2 = pad_sequences(x_test_tokens, maxlen=max_tokens, padding='post', truncating='post')

    
    # Get input and output of saliency scores
    input_tensors = [model.input, K.learning_phase()]
    saliency_input = model.layers[1].output # before split into branches
    saliency_output = model.layers[12].output # class score
    gradients = model.optimizer.get_gradients(saliency_output,saliency_input)
    compute_gradients = K.function(inputs=input_tensors,outputs=gradients)
     
    
    print("Predicted labels for these examples are: ", y_pred_class )

    for doc in x_test_pad2:
        matrix = compute_gradients([np.array([doc]),0])[0][0,:,:]
        tokens = [index_to_word[elt] for elt in doc if elt!=0]
        to_plot = np.absolute(matrix[:len(tokens),:])
        fig, ax = plt.subplots()
        heatmap = ax.imshow(to_plot, cmap=plt.cm.BuPu,interpolation='nearest',aspect='auto')
        ax.set_yticks(np.arange(len(tokens)))
        ax.set_yticklabels(tokens)
        ax.tick_params(axis='y', which='major', labelsize=20)
        fig.colorbar(heatmap)
        fig.set_size_inches(14,9)
        fig.show()        
    


if __name__ == '__main__':
    main()
