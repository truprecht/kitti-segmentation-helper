from __future__ import division
from sys import argv
import numpy as np
from cv2 import resize, imread, IMREAD_GRAYSCALE

def labelmasks(labelarray):
    maskdict = {}
    for label in np.unique(labelarray):
        if label == 0: continue
        maskdict[label] = np.array(labelarray == label, dtype = np.uint8)
    return maskdict

def foregroundmask(labelarray):
    return np.array(labelarray > 0, dtype = np.uint8)

def iou(prediction, groundtruth):
    return np.sum(np.logical_and(prediction, groundtruth)) / np.sum(np.logical_or(prediction, groundtruth))

def overlapped(prediction, groundtruth):
    return np.sum(np.logical_and(prediction, groundtruth))

def coverage(instance, predictions):
    match = max(predictions.iterkeys(), key = lambda label: overlapped(instance, predictions[label]))
    return iou(instance, predictions[match])

def precision(prediction, groundtruth):
    tp = np.sum(np.logical_and(prediction, groundtruth))
    divisor = np.sum(prediction)
    return tp / divisor if divisor > 0 else 1

scores = []

assert len(argv) == 2
with open(argv[1]) as labelpairs:
    for labelpair in labelpairs:
        predictionfilename, labelfilename = labelpair.split()

        assert labelfilename.endswith(".png")
        assert predictionfilename.endswith(".png") or predictionfilename.endswith(".dat")

        groundtruth = imread(labelfilename, IMREAD_GRAYSCALE)
        if predictionfilename.endswith(".png"):
            prediction = imread(predictionfilename, IMREAD_GRAYSCALE)
        elif predictionfilename.endswith(".txt"):
            prediction = np.argmax(np.fromfile(predictionfilename, dtype = np.uint8).reshape(groundtruth.shape, order = 'F'), axis = 2)
        
        prediction_foreground, groundtruth_foreground = foregroundmask(prediction), foregroundmask(groundtruth)
        prediction_masks, groundtruth_masks = labelmasks(prediction), labelmasks(groundtruth)

        tp_instances = np.sum([np.any([iou(gti, pi) > .5 for pi in prediction_masks.values()]) for gti in groundtruth_masks.values()])
        insPrec = tp_instances / len(prediction_masks)
        insRec = tp_instances / len(groundtruth_masks)
        scores.append(( iou(prediction_foreground, groundtruth_foreground)  # class-level iou
                      , np.average([coverage(gti, prediction_masks) for gti in groundtruth_masks.values()], weights = [np.sum(gti) for gti in groundtruth_masks.values()]) # mean weighted coverage
                      , np.average([coverage(gti, prediction_masks) for gti in groundtruth_masks.values()]) # mean unweighted coverage
                      , np.average([precision(pi, groundtruth_foreground) for pi in prediction_masks.values()]) # average (instance - class) precision
                      , np.average([precision(gti, prediction_foreground) for gti in groundtruth_masks.values()]) # average (class - instance) recall
                      , np.sum([not np.any(np.logical_and(pi, groundtruth_foreground)) for pi in prediction_masks.values()]) # average number of false - positive instances
                      , np.sum([not np.any(np.logical_and(gti, prediction_foreground)) for gti in groundtruth_masks.values()]) # average number of false - negative instances
                      , insPrec # average instantiation precision
                      , insRec # average instantiation recall
                      , 2 * insPrec * insRec / (insPrec + insRec) if insPrec + insRec > 0 else 0 # average instantiation f1
                      ))
    print "%f %f %f %f %f %f %f %f %f %f" % tuple(np.average(scores, axis = 0))