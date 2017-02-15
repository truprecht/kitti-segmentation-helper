import cv2
import numpy as np
from sys import argv

assert len(argv) > 3, "asd"

filename = argv[1]
toone = int(argv[2])
ofile = argv[3]

img = cv2.imread(filename)
cv2.imwrite(ofile, np.array(img == toone, dtype=np.uint8))