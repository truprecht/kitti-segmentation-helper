#!/usr/bin/python2

import cv2
import numpy as np

def fill_top(labels, height):
    temp = np.zeros((height, labels.shape[1]))
    temp[height-labels.shape[0]:height,:] = labels
    return temp

if __name__ == "__main__":
    from sys import argv

    assert len(argv) == 6, "use " + argv[0] + " <image> <original height> <new width> <new height> <rescaled file>"

    W, H = int(argv[3]), int(argv[4])
    SRC = cv2.imread(argv[1], cv2.IMREAD_GRAYSCALE)

    FILLED = fill_top(SRC, int(argv[2]))
    cv2.imwrite(argv[5], cv2.resize(FILLED, (W, H), interpolation=cv2.INTER_NEAREST))
