from __future__ import division
from sys import argv
import numpy as np
from cv2 import resize, imread, IMREAD_GRAYSCALE
from multiprocessing import Pool
from h5py import File
from scipy.io import loadmat


# load a label from a file name
def load(datafile, scale = None):
    if datafile.endswith(".png"):
        return imread(datafile, IMREAD_GRAYSCALE)
    
    if datafile.endswith(".dat"):
        scores = np.fromfile(predictionfilename, dtype = np.uint8).reshape(groundtruth.shape, order = 'F')
    
    if datafile.endswith(".mat"):
        try:
            # (41,     41,    6)
            # (height, width, channels)
            scores = loadmat(datafile)["data"][:, :, :, 0]
        except Exception, e:
            # sometimes caffe decides to return matlab 7.3 matrices...
            # (6,        41,     41)
            # (channels, height, width)
            scores = np.transpose(File(datafile)["data"][0], (1, 2, 0))
    
    if not scale is None:
        scores = resize(scores, scale)

    return np.argmax(scores, axis = 2)

# cuts binary masks for each label in an image (all but 0), stores it in a dic label -> mask
def labelmasks(labelarray):
    maskdict = {}
    for label in np.unique(labelarray):
        if label == 0: continue
        maskdict[label] = np.array(labelarray == label, dtype = np.uint8)
    return maskdict


# cuts exactly one mask for an image where labels are > 0
def foregroundmask(labelarray):
    return np.array(labelarray > 0, dtype = np.uint8)


# computes the intersection over union score for two binary masks
def iou(prediction, groundtruth):
    divisor = np.sum(np.logical_or(prediction, groundtruth))
    return np.sum(np.logical_and(prediction, groundtruth)) / divisor if divisor > 0 else 1 

# counts the overlapping pixels for two masks
def overlapped(prediction, groundtruth):
    return np.sum(np.logical_and(prediction, groundtruth))


# computes the coverage score for a mask and a dic of masks:
# - matches the object instance mask with the best overlapping mask of the dic
# - returns the i-o-u score of that match
def coverage(instance, predictions):
    if len(predictions) == 0: return 0
    match = max(predictions.iterkeys(), key = lambda label: overlapped(instance, predictions[label]))
    return iou(instance, predictions[match])


# computes the precision of a predicted mask considering a gt mask
# - true positives are pixels that are true in both masks
# - true positive + false positive pixels are all true pixels of the prediction
def precision(prediction, groundtruth):
    tp = np.sum(np.logical_and(prediction, groundtruth))
    divisor = np.sum(prediction)
    return tp / divisor if divisor > 0 else 1


# returns a list of scores for a predction / gt label pair
def scores(labelpair):
    predictionfilename, labelfilename = labelpair.split()

    groundtruth = load(labelfilename)
    height, width = groundtruth.shape
    prediction = load(predictionfilename, (width, height))

    prediction_foreground, groundtruth_foreground = foregroundmask(prediction), foregroundmask(groundtruth)
    prediction_masks, groundtruth_masks = labelmasks(prediction), labelmasks(groundtruth)

    tp_instances = np.sum([np.any([iou(gti, pi) > .5 for pi in prediction_masks.values()]) for gti in groundtruth_masks.values()])
    insPrec = tp_instances / len(prediction_masks) if len(prediction_masks) > 0 else 1
    insRec = tp_instances / len(groundtruth_masks) if len(groundtruth_masks) > 0 else 1

    instances_area = [np.sum(gti) for gti in groundtruth_masks.values()]

    return  ( iou(prediction_foreground, groundtruth_foreground)  # class-level iou
            , np.average([coverage(gti, prediction_masks) for gti in groundtruth_masks.values()], weights = instances_area) if np.sum(instances_area) > 0 else 1 # mean weighted coverage
            , np.average([coverage(gti, prediction_masks) for gti in groundtruth_masks.values()]) if len(groundtruth_masks) > 0 else 1 # mean unweighted coverage
            , np.average([precision(pi, groundtruth_foreground) for pi in prediction_masks.values()]) if len(prediction_masks) > 0 else 1 # average (instance - class) precision
            , np.average([precision(gti, prediction_foreground) for gti in groundtruth_masks.values()]) if len(groundtruth_masks) > 0 else 1 # average (class - instance) recall
            , np.sum([not np.any(np.logical_and(pi, groundtruth_foreground)) for pi in prediction_masks.values()]) # average number of false - positive instances
            , np.sum([not np.any(np.logical_and(gti, prediction_foreground)) for gti in groundtruth_masks.values()]) # average number of false - negative instances
            , insPrec # average instantiation precision
            , insRec # average instantiation recall
            , 2 * insPrec * insRec / (insPrec + insRec) if insPrec + insRec > 0 else 0 # average instantiation f1
            )

if __name__ == "__main__":
    assert len(argv) == 3
    
    processors = Pool(int(argv[2]))
    with open(argv[1]) as labelpairs_:
        labelpairs = labelpairs_.readlines()
        score = np.average( processors.map(scores, labelpairs), axis = 0 )
        
        print "%f %f %f %f %f %f %f %f %f %f" % tuple(score)