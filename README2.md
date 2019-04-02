# PUBP8813-ECON8803
Repository for Problem Set 3 : Sentiment analysis using CNN

# Popular-Sentiment-of-Electric-Vehicles-in-the-United-States
This code replicates protocols in the manuscript: “Popular Sentiment of Electric Vehicle Owners in the United States.” Proprietary data is restricted to authorized researchers only.
The Python scripts will run the neural network-based language models for sentiment analysis. 

[![DOI](https://zenodo.org/badge/149052541.svg)](https://zenodo.org/badge/latestdoi/149052541)

## Requirements

### Python setup
Python code is written in Python 3.6. You can verify the version of Python by running the following command.

```
$ python —-version
# Python 3.6.x
```

Uses the following python packages: `gensim 3.4.0 keras 2.2.0 numpy 1.14.3 pandas 0.23.0 scikit-learn 0.19.1 tensorflow 1.9.0rc1`. Can install with `pip` as follows:

```
$ pip install gensim==3.4.0
$ pip install keras==2.2.0
$ pip install numpy==1.14.3
$ pip install pandas==0.23.0
$ pip install scikit-learn==0.19.1
$ pip install tensorflow==1.9.0rc1
```

NOTE: Using tensorflow-gpu will result in a much faster training time of the CNN, but results may differ slightly from ones reported in the paper. This is because the training of the CNN used in this paper was done using a cpu.

### Install *word2vec* vectors
Using the pre-trained word2vec vectors requires downloading the binary file from (https://code.google.com/p/word2vec/)

[Download link](https://drive.google.com/uc?id=0B7XkCwpI5KDYNlNUTTlSS21pQmM&export=download) (1.5Gb)

The file name is `GoogleNews-vectors-negative300.bin.gz`. This file must be placed in the same directory as the python files in order to be used without modifying the code.
