#/usr/bin/python2
import cv2
import numpy as np
from sys import argv
from os import getcwd

STEPSIZE = 20
WD = getcwd() + "/"

if __name__ == "__main__":
    assert len(argv) == 4
    imagefile = argv[1]
    pwidth = int(argv[2])
    pheight = int(argv[3])
    print "extracting %dx%d patches" %(pwidth, pheight)

    img = cv2.imread(imagefile)
    assert img is not None

    test_formatted = ""
    test_id = ""
    ranges = ""
    id = 1
    
    iheight, iwidth, _ = img.shape
    for y in range(0, iheight - pheight, STEPSIZE):
        for x in range(0, iwidth - pwidth, STEPSIZE):
            id += 1
            strid = "{:06d}".format(id)

            cv2.imwrite(strid + ".png", img[y:y+pheight, x:x+pwidth])
            test_formatted += WD + strid + ".png\n"
            test_id += strid + "\n"
            ranges += strid + ",%d,%d,%d,%d\n" %(y+1, y+pheight, x+1, x+pwidth)

    open("test_list.txt", "w").write(test_formatted)
    open("test_list_id_only.txt", "w").write(test_id)
    open("ranges.txt", "w").write(ranges)