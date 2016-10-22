#/usr/bin/python2
import cv2
import numpy as np
from sys import argv
from os import getcwd, makedirs
from re import search

WD = getcwd() + "/"

if __name__ == "__main__":
    assert len(argv) == 8, "Use " + argv[0] + " <img> <patch width> <patch height> <stride (x)> <y offset> <output dir> <name postfix>"
    imagefile = argv[1]
    imgfilename = search("([^\./]+)\.\w+$", imagefile).group(1)
    pwidth = int(argv[2])
    pheight = int(argv[3])
    stride = int(argv[4])
    y_off = int(argv[5])
    outputdir = argv[6]
    postfix = argv[7]
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
    
    # fix y for last row only
    ### for y in range(0, iheight - pheight, stride):
    y = iheight - y_off

    xrange = range(0, iwidth - pwidth, stride)
    last = iwidth - pwidth 
    xrange += [last] if not last in xrange else []  
    
    for x in xrange:
        id += 1
        #strid = idprefix + "{:06d}".format(id)
        strid = imgfilename + postfix + "_{:02d}".format(id)

        cv2.imwrite(outputdir + strid + ".png", img[y:y+pheight, x:x+pwidth])
        test_formatted += outputdir + strid + ".png\n"
        test_id += strid + "\n" 
        open(roidir + strid + ".txt", "wb").write("%d %d %d %d" %(y+1, y+pheight, x+1, x+pwidth))

    open(outputdir + "test_list.txt", "w").write(test_formatted)
    open(outputdir + "test_list_id_only.txt", "w").write(test_id)