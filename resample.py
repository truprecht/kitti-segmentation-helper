import numpy as np
from sys import argv
from os import listdir, makedirs
from scipy.io import loadmat
import cv2

import struct

if __name__ == "__main__":
    assert len(argv) == 5, "use " + argv[0] + " <input folder> <new width> <new height> <output folder>"

    inputdir = argv[1]
    nwidth = int(argv[2])
    nheight = int(argv[3])
    outputdir = argv[4]
    if outputdir[-1] != "/": outputdir += "/"
    if inputdir[-1] != "/": inputdir += "/"
    try:
        makedirs(outputdir[:-1])
    except Exception, _:
        pass

    filelist = ""

    # resample all files in input dir, convert result to float binary and store in output dir
    for file in listdir(inputdir):
        filepath = inputdir + file
        print "processing file %s" %(file)
        try:
            assert file.endswith(".mat"), "Filename should end with .mat"
            mat = loadmat(filepath)["data"]

            ofile = file.replace("_blob_0.mat", ".dat")
            filelist += ofile + "\n"

            oheight, owidth, cs, iss = mat.shape
            omat = cv2.resize(mat[:,:,:, 0], (nwidth, nheight))

            # output
            with open(outputdir + ofile, "wb") as bin:
                for channel in range(0, cs):
                    for col in range(0, nwidth):
                        for row in range(0, nheight):
                            bin.write(struct.pack('f', omat[row, col, channel]))

        except Exception, e:
            print "... skipping b/c %s" %(str(e))
    
    with open(outputdir + "filelist.txt", "a") as file:
        file.write(filelist)
    
    print "done"