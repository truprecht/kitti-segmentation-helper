import numpy as np
from sys import argv
from os import listdir, makedirs
from scipy.io import loadmat
import cv2

import struct

if __name__ == "__main__":
    assert len(argv) == 5, "use " + argv[0] + " <input folder> <new width> <new height> <output folder>"

    #mat = np.array(hdf.File(argv[1])["data"])
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

    for file in listdir(inputdir):
        filepath = inputdir + file
        print "processing file %s" %(file)
        try:
            assert file.endswith(".mat"), "Filename should end with .mat"
            mat = loadmat(filepath)["data"]

            #iss, cs, oheight, owidth = mat.shape
            oheight, owidth, cs, iss = mat.shape
            # resample
            nmat = np.zeros((iss, cs, nheight, nwidth))
            for i in range(0, iss):
                for c in range(0, cs):
                    for y in range(0, nheight):
                        for x in range(0, nwidth):
                            nmat[i,c,y,x] = mat[int( (y+.5) * float(oheight)/nheight ), int( (x+.5) * float(owidth)/nwidth ), c, i]
                    nmat[i,c] = cv2.GaussianBlur(nmat[i,c], (5,5), 0)

            # dump float binaries
            ofile = file.replace("_blob_0.mat", ".dat")
            filelist += ofile + "\n"
            bin = open(outputdir + ofile, "wb")
            nmat = nmat.flatten()
            s = struct.pack('f'*len(nmat), *nmat)
            bin.write(s)
            bin.close()
        except Exception, e:
            print "... skipping b/c %s" %(str(e))
    
    with open(outputdir + "filelist.txt", "a") as file:
        file.write(filelist)
    
    print "done"