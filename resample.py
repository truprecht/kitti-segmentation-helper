#!python2
"""
    resample each data array of a mat file in folder to size
"""

from os import listdir, makedirs, error
from sys import argv

import numpy as np
from h5py import File
from scipy.io import loadmat

# pylint: disable=E0611
from cv2 import resize

if __name__ == "__main__":
    assert len(argv) == 5, \
         "use " + argv[0] + " <input folder> <new width> <new height> <output folder>"

    # pylint: disable=C0103
    inputdir = argv[1]
    nwidth = int(argv[2])
    nheight = int(argv[3])
    outputdir = argv[4]

    if outputdir[-1] != "/":
        outputdir += "/"
    if inputdir[-1] != "/":
        inputdir += "/"
    try:
        makedirs(outputdir[:-1])
    except error, _:
        pass

    filelist = ""

    # resample all files in input dir, convert result to float binary and store in output dir
    for filename in listdir(inputdir):
        filepath = inputdir + filename
        print "processing file %s" %(filename)
        try:
            assert filename.endswith(".mat"), "Filename should end with .mat"
            try:
                # (41,      41,     6)
                # (height,  width,  channels)
                mat = loadmat(filepath)["data"][:, :, :, 0]
            except Exception, e:
                # sometimes caffe decides to return matlab 7.3 matrices...
                # (6,           41,     41)
                # (channels,    width,  height)
                mat = File(filepath)["data"][0]
                mat = np.swapaxes(mat, 0, 2)

            omat = resize(mat, (nheight, nwidth))

            ofile = filename.replace("_blob_0.mat", ".dat")
            filelist += ofile + "\n"

            # output
            with open(outputdir + ofile, "wb") as binfile:
                omat.flatten(order="F").tofile(binfile)

        except Exception, e:
            print "... skipping b/c %s" %(str(e))

    with open(outputdir + "filelist.txt", "a") as filelistfile:
        filelistfile.write(filelist)

    print "done"
