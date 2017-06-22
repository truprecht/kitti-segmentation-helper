#!/usr/bin/env python2
"""
    provides methods to cut image patches as used in segmentation algorithm
"""

from os import error, makedirs
from re import search
from sys import argv

import numpy as np
from multiprocessing import Pool

# pylint: disable=E0611
from cv2 import imread, imwrite, IMREAD_GRAYSCALE


def save_patches(patchlist, output_folder, basename, name_postfix="_"):
    """
        save a list of patch tuples using autoincrement names
    """
    autoinc = 1
    filenames = []
    
    for (patch, label, roi) in patchlist:
        patchfilename = "{basename}{postfix}_{uid:02d}.png".format( \
            basename=basename \
            , uid=autoinc \
            , postfix=name_postfix \
            )
        imwrite(output_folder + patchfilename, patch)
        with open(output_folder + patchfilename.replace(".png", ".txt"), "w") as roifile:
            roifile.write(" ".join([str(r) for r in roi]))
        if label is not None:
            labelfilename = "{basename}{postfix}_{uid:02d}_annot.png".format( \
                basename=basename \
                , uid=autoinc \
                , postfix=name_postfix \
                )
            imwrite(output_folder + labelfilename, label)
            filenames.append("{patch} {label}".format(patch=output_folder + patchfilename \
                                                     , label=output_folder + labelfilename \
                                                     ))
        else:
            filenames.append(output_folder + patchfilename)
        autoinc += 1
    
    return filenames

def crop(image, pwidth, pheight, stride, y_off, label_image=None):
    """
        synchronously crop image patches from two images
    """
    assert image is not None, "image could not be read"

    iheight, iwidth, _ = image.shape

    # fix y for last row only w/ offset
    fixed_y = iheight - y_off

    range_x = range(0, iwidth - pwidth, stride)
    # force rightmost patch
    last = iwidth - pwidth
    range_x += [last] if not last in range_x else []

    patch_tuples = []

    for current_x in range_x:
        roi = (fixed_y+1, fixed_y+pheight, current_x+1, current_x+pwidth)
        patch = np.array(image[fixed_y:fixed_y+pheight, current_x:current_x+pwidth])
        labels = None
        
        if label_image is not None:
            labels = np.array(label_image[fixed_y:fixed_y+pheight, current_x:current_x+pwidth])

        patch_tuples.append((patch, labels, roi))

    return patch_tuples


def crop_global(images):
    global pwidth, pheight, stride, yoff, output_folder, postfix
    basename = search(r"""([^\./]+)\.\w+$""", images[0]).group(1)
    
    try:
        (imagefile, labelfile) = images
        image = imread(imagefile)
        label = imread(labelfile)
    except:
        (imagefile, ) = images
        image = imread(imagefile)
        label = None
    
    return save_patches( crop(image, pwidth, pheight, stride, yoff, label), output_folder, basename, postfix )

def read_image_list(listfile):
    for line in listfile:
        yield line.strip().split()

if __name__ == "__main__":
    assert len(argv) == 8 or len(argv) == 9, \
        "Use " + argv[0] + " \
        <img> \
        <patch width> \
        <patch height> \
        <stride (x)> \
        <y offset> \
        <output dir> \
        <name postfix> \
        [<annotation file>]"

    if argv[6][-1] != "/":
        argv[6] += "/"
    try:
        makedirs(argv[6][:-1])
    except error:
        pass

    global pwidth, pheight, stride, yoff, output_folder, postfix
    (pwidth, pheight, stride, yoff) = map(int, argv[2:6])
    (output_folder, postfix) = argv[6:8]

    cpus = Pool(24)
    with open(argv[1]) as listfile:
        for line in cpus.map(crop_global, read_image_list(listfile)):
            print "\n".join(line)