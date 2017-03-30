import caffe
import lmdb
import numpy as np
import cv2

from sys import argv

if __name__ == "__main__":
    assert len(argv) == 3, "Use %s <image list> <database file>"

    patchdb = lmdb.open(argv[2] + ".im", map_size=int(1e12))
    labeldb = lmdb.open(argv[2] + ".gt", map_size=int(1e12))

    with patchdb.begin(write=True) as ptx:
        with labeldb.begin(write=True) as ltx:
            with open(argv[1]) as files:
                for line in files:
                    image, annot = line.split(" ")
                    x = cv2.imread(image).transpose((2,0,1))
                    ptx.put(image.encode("ascii"), caffe.io.array_to_datum(x).SerializeToString())
                    y = cv2.imread(annot, cv2.IMREAD_GRAYSCALE)
                    ltx.put(image.encode("ascii"), caffe.io.array_to_datum(y).SerializeToString())