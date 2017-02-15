import numpy as np
from h5py import File
#from scipy.io import loadmat

import cv2
from sys import argv

assert len(argv) > 2

gt = cv2.imread(argv[1], cv2.IMREAD_GRAYSCALE)
gtheight, gtwidth = gt.shape

try:
    # (41,      41,     6)
    # (height,  width,  channels)
    #pred = loadmat(argv[2])["data"][:, :, :, 0]
    raise Exception("")
except Exception, e:
    # sometimes caffe decides to return matlab 7.3 matrices...
    # (6,           41,     41)
    # (channels,    width,  height)
    pred = File(argv[2])["data"][0]
    pred = np.swapaxes(pred, 0, 2)

pred = cv2.resize(pred, (gtwidth, gtheight))
classpred = np.array(np.argmax(pred, axis=2) != 0, dtype=np.uint8)

tp = np.logical_and(classpred, gt)
fp = np.logical_and(classpred, np.logical_not(gt))
fn = np.logical_and(np.logical_not(classpred), gt)

tp_, fp_, fn_ = np.sum(tp), np.sum(fp), np.sum(fn)

precision = float(tp_) / (fp_ + tp_)
recall = float(tp_) / (fn_ + tp_)

print "%d, %d" %(precision, recall)