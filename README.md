# Popular-Sentiment-of-Electric-Vehicles-in-the-United-States
This code replicates protocols in the manuscript: “Popular Sentiment of Electric Vehicle Owners in the United States.” Proprietary data is restricted to authorized researchers only.
The Python scripts will run the neural network-based language models for sentiment analysis. The R scripts will produce the tables and figures shown in the paper.

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


### R setup
R code written using version 3.5.0.

You will need to install the following packages, and set the working directory to this root folder:

```
> install.packages("readr")
> install.packages("dplyr")
> install.packages("data.table")
> install.packages("ggplot2", dep = TRUE)
> install.packages("ggsignif")
> install.packages("gmodels")

> setwd(<path_to_this_folder>)
```

### Install *word2vec* vectors
Using the pre-trained word2vec vectors requires downloading the binary file from (https://code.google.com/p/word2vec/)

[Download link](https://drive.google.com/uc?id=0B7XkCwpI5KDYNlNUTTlSS21pQmM&export=download) (1.5Gb)

The file name is `GoogleNews-vectors-negative300.bin.gz`. This file must be placed in the same directory as the python files in order to be used without modifying the code.

### Data files
In order to reproduce the results and tables you wil need the following proprietary data files (authorized researchers only):

- training_data.csv
- NA Reviews Data.csv
- NA_Location_Data_7-16-18.csv


## Steps to Replicate: 

1. Ensure `training_data.csv` and `NA Reviews Data.csv` are in the working directory.

2. Run cnn_sentiment.py to evaluate performance of CNN. This may take 20-30 minutes to run on a cpu

```
$ python cnn_sentiment.py
# Using TensorFlow backend.
# 2018-09-15 20:58:41.430100: I tensorflow/core/platform/cpu_feature_guard.cc:141] Your CPU supports instructions that this TensorFlow binary was not compiled to use: AVX2 FMA
# Train size: 7162
# Test size: 1791
# Loading pre-trained word embeddings..
# done in 198.498287s
# creating embedding matrix..
# done in 0.000003s
# Epoch 1/3
# 7162/7162 [==============================] - 1502s 210ms/step - loss: 0.5105 - acc: 0.7517
# Epoch 2/3
# 7162/7162 [==============================] - 1499s 209ms/step - loss: 0.3302 - acc: 0.8567
# Epoch 3/3
# 7162/7162 [==============================] - 1492s 208ms/step - loss: 0.2405 - acc: 0.9037
# Generating predictions on the test set...
#
# Accuracy: 84.37%
# Precision: 0.88
# Recall: 0.82
```

3. Run lstm_sentiment.py to evaluate performance of LSTM. This may take 60 minutes to run on a cpu

```
$ python lstm_sentiment.py
# Accuracy: 83.81%
# Precision: 0.85
# Recall: 0.86
```


4. Run lr_sentiment.py to evaluate performance of Logistic Regression

```
$ python lr_sentiment.py
# Accuracy: 78.5%
# Precision: 0.79
# Recall: 0.82
```

5. Run svm_sentiment.py to evaluate performance of SVM

```
$ python svm_sentiment.py
# Accuracy: 76.5%
# Precision: 0.78
# Recall: 0.79
```


6. Run cnn_make_predictions.py to generate sentiment predictions for all reviews. This will create the `NA Reviews Data Sentiment.csv` file. This may take around an hour to run on a cpu.

```
$ python cnn_make_predictions.py
# Using TensorFlow backend.
# 2018-09-15 22:23:14.930414: I tensorflow/core/platform/cpu_feature_guard.cc:141] Your CPU supports instructions that this TensorFlow binary was not compiled to use: AVX2 FMA
# sys:1: DtypeWarning: Columns (2) have mixed types. Specify dtype option on import or set low_memory=False.
# Train size: 8953
# Predict size: 140188
# Loading pre-trained word embeddings..
# done in 193.541409s
# creating embedding matrix..
# done in 0.000003s
# Epoch 1/3
# 8953/8953 [==============================] - 1876s 210ms/step - loss: 0.4838 - acc: 0.7697
# Epoch 2/3
# 8953/8953 [==============================] - 1873s 209ms/step - loss: 0.3162 - acc: 0.8631
# Epoch 3/3
# 8953/8953 [==============================] - 1866s 208ms/step - loss: 0.2354 - acc: 0.9067
# Predicting sentiment for entire dataset...
# done in 6714.033920s
```

7. Run create_final_analysis_data.py to create final predictions dataset by replacing machine predictions of reviews that are in training set with ground truth labels from humans. This will generate the `NA Reviews Data Best Sentiment.csv` file.

```
$ python create_final_analysis_data.py
# sys:1: DtypeWarning: Columns (3) have mixed types. Specify dtype option on import or set low_memory=False.
```

8. The rest of the steps are in R. Ensure `NA Reviews Data Best Sentiment.csv` and `NA_Location_Data_7-16-18.csv` are in the working directory. 

9. Run final_dataset.R to generate `final_data.csv`

10. Run final_analysis.Rmd. All graphics and tables (except for the t-tests for CBSAs and States) will display at the bottom of the file. 

11. Run t_tests_stateCBSA.Rmd. It will create two .txt files that show output of the t-tests.

## Saliency heatmap generation for CNN interpretability
Run cnn_visualization_final.py to create saliency heatmaps for interpretability of the CNN model. The code is referenced from Tixier, A. J.-P.  Notes on deep learning for nlp.arXiv933preprint arXiv:1808.09772(2018).
<iframe src="saliency_heatmap" width='100%" height="100%">

## Econometric Analysis of the Sentiment
To replicate the protocols for the statistical analysis using review rate and sentiment score, see FRM_NegScore.R.


 
