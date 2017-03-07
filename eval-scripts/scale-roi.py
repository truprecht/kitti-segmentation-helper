#!/usr/bin/python2

def rescale(y1, y2, x1, x2, w, h):
    xscale = float(w) / float(x2 - x1)
    yscale = float(h) / float(y2 - y1)

    y1_ = int(round(y1 * yscale))
    x1_ = int(round(x1 * xscale))

    return (y1_, y1_ + h, x1_, x1_ + w)

if __name__ == "__main__":
    from sys import argv

    assert len(argv) == 3, "use " + argv[0] + " <roi file> <new width> <new height>"

    with open(argv[1]) as roifile:
        oy1, oy2, ox1, ox2 = map(int, roifile.readline().split(" "))
        print " ".join( map(str, rescale(oy1, oy2, ox1, ox2, int(argv[2]), int(argv[3]))) )

