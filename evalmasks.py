#!/usr/bin/python2

import cv2
import numpy as np
from sys import argv

if __name__ == "__main__":
    assert len(argv) == 5, \
        "use " + argv[0] + " <prediction> <orig. width> <orig. height> <output folder>"

    ofolder = argv[4] if argv[4][-1] == "/" else argv + "/"
    filename = argv[1].split("/")[-1].split(".")[0]

    oheight, owidth = int(argv[3]), int(argv[2])

    prediction_ = cv2.imread(argv[1], cv2.IMREAD_GRAYSCALE)
    pheight, pwidth = prediction_.shape

    # add zero padding to match original shape
    prediction = np.zeros((oheight, owidth))
    prediction[oheight-pheight:oheight, owidth-pwidth:owidth] = prediction_

    for i in np.unique(prediction):
        if i == 0:
            id = 0
        else:
            id = 26
        maskfilename = "%s%d%s" %(filename, i, ".png")
        cv2.imwrite(ofolder + maskfilename, np.array(prediction == i, dtype=np.uint8))
        print "%s %d %d" %(maskfilename, id, 1)