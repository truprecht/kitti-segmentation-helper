import h5py as hdf
import numpy as np
from sys import argv
from scipy.misc import imresize

import struct

if __name__ == "__main__":
    if len(argv) == 4: 
        mat = np.array(hdf.File(argv[1])["data"])
        nwidth = int(argv[2])
        nheight = int(argv[3])

        iss, cs, oheight, owidth = mat.shape
        # resample
        nmat = np.zeros((iss, cs, nheight, nwidth))
        for i in range(0, iss):
            for c in range(0, cs):
                for y in range(0, nheight):
                    for x in range(0, nwidth):
                        nmat[i,c,y,x] = mat[i,c, int( (y+.5) * float(oheight)/nheight ), int( (x+.5) * float(owidth)/nwidth )]

        # TODO dump float binaries
        bin = open(argv[1] + ".bin", "wb")
        mat = mat.flatten()
        s = struct.pack('f'*len(mat), *mat)
        bin.write(s)
        bin.close()