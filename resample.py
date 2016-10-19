import h5py as hdf
import numpy as np
from sys import argv
from scipy.misc import imresize
from os import listdir, mkdirs

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
        mkdirs(outputdir[:-1])
    except Exception, _:
        pass

    for file in listdir(inputdir):
        filepath = inputdir + file
        print "processing file %s" %(file)
        try:
            assert file.endswith(".mat"), "Filename should end with .mat"
            mat = np.array(hdf.File(filepath)["data"])

            iss, cs, oheight, owidth = mat.shape
            # resample
            nmat = np.zeros((iss, cs, nheight, nwidth))
            for i in range(0, iss):
                for c in range(0, cs):
                    for y in range(0, nheight):
                        for x in range(0, nwidth):
                            nmat[i,c,y,x] = mat[i,c, int( (y+.5) * float(oheight)/nheight ), int( (x+.5) * float(owidth)/nwidth )]

            # TODO dump float binaries
            bin = open(outputdir + file.replace(".mat", ".dat"), "wb")
            mat = mat.flatten()
            s = struct.pack('f'*len(mat), *mat)
            bin.write(s)
            bin.close()
        except Exception, e:
            print "... skipping b/c %s" %(str(e))
    print "done"