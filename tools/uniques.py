import numpy as np
import cv2

from sys import argv


if __name__ == "__main__":
    assert len(argv) == 2, "Prints the number of unique colors in a grayscale image. Use %s <image>."
    
    print len(np.unique(cv2.imread(argv[1], cv2.IMREAD_GRAYSCALE)))
