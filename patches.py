#/usr/bin/python2
import cv2
import numpy as np
from sys import argv
from os import getcwd, makedirs

WD = getcwd() + "/"

if __name__ == "__main__":
    assert len(argv) == 7, "Use " + argv[0] + " <img> <patch width> <patch height> <stride> <output dir> <name prefix>"
    imagefile = argv[1]
    pwidth = int(argv[2])
    pheight = int(argv[3])
    stride = int(argv[4])
    outputdir = argv[5]
    idprefix = argv[6]
    if outputdir[-1] != "/": outputdir += "/"
    roidir = outputdir + "roi/"
    try:
        makedirs(outputdir[:-1])
        makedirs(roidir[:-1])
    except Exception, _:
        pass
    

    img = cv2.imread(imagefile)
    assert img is not None, "Image [%s] could not be read" %(imagefile)

    test_formatted = ""
    test_id = ""
    id = 0
    
    iheight, iwidth, _ = img.shape
    for y in range(0, iheight - pheight, stride):
        for x in range(0, iwidth - pwidth, stride):
            id += 1
            strid = idprefix + "{:06d}".format(id)

            cv2.imwrite(outputdir + strid + ".png", img[y:y+pheight, x:x+pwidth])
            test_formatted += outputdir + strid + ".png\n"
            test_id += strid + "\n" 
            open(roidir + strid + ".txt", "wb").write("%d %d %d %d" %(y+1, y+pheight, x+1, x+pwidth))

    open(outputdir + "test_list.txt", "w").write(test_formatted)
    open(outputdir + "test_list_id_only.txt", "w").write(test_id)