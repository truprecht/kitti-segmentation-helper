#python2
"""
    provides methods to cut image patches as used in segmentation algorithm
"""

from os import error, makedirs
from re import search
from sys import argv

import numpy as np

# pylint: disable=E0611
from cv2 import imread, imwrite, IMREAD_GRAYSCALE


def save_patches(patchlist, output_folder, basename, name_postfix="_"):
    """
        save a list of patch tuples using autoincrement names
    """
    autoinc = 1
    for (patch, label) in patchlist:
        patchfilename = "{basename}{postfix}_{uid:02d}.png".format( \
            basename=basename \
            , uid=autoinc \
            , postfix=name_postfix \
            )
        imwrite(output_folder + patchfilename, patch)
        if label is not None:
            labelfilename = "{basename}{postfix}_{uid:02d}_annot.png".format( \
                basename=basename \
                , uid=autoinc \
                , postfix=name_postfix \
                )
            imwrite(output_folder + labelfilename, label)
            print "{patch} {label}".format(patch=patchfilename, label=labelfilename)
        else:
            print patchfilename
        autoinc += 1


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
        patch = np.array(image[fixed_y:fixed_y+pheight, current_x:current_x+pwidth])
        labels = None
        if label_image is not None:
            labels = np.array(label_image[fixed_y:fixed_y+pheight, current_x:current_x+pwidth])

            # normalize train IDs to increment from 1 to |l| in each patch locally
            i = 1
            for label in np.unique(labels):
                np.place(labels, labels == label, [i])
                i += 1

        patch_tuples.append((patch, labels))

    return patch_tuples


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

    save_patches( \
        crop( \
            imread(argv[1]) \
            , int(argv[2]) \
            , int(argv[3]) \
            , int(argv[4]) \
            , int(argv[5]) \
            , label_image=(imread(argv[8], IMREAD_GRAYSCALE) if len(argv) == 9 else None) \
            ) \
        , argv[6] \
        , search(r"""([^\./]+)\.\w+$""", argv[1]).group(1) \
        , name_postfix=argv[7] \
        )
