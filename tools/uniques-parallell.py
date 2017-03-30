import numpy as np
import cv2

from multiprocessing import Pool
from glob import glob
from sys import argv
from re import search

def get_instances(filepath):
    try:
        patchtype = search("(\d+)_\d+_annot.png", filepath)
        return "%s, %d" %(patchtype.group(1), cv2.imread(filepath, cv2.IMREAD_GRAYSCALE).max())
    except Exception, e:
        return "error: %s" %(str(e),)

if __name__ == "__main__":
    assert len(argv) == 2, "Prints the number of unique colors in a grayscale image. Use %s <image folder / filename pattern>."
    
    p = Pool(processes=24)
    for nri in p.map(get_instances, glob(argv[1])):
        print nri
