#!/usr/bin/python2

if __name__ == "__main__":
    from sys import argv

    assert len(argv) == 5, "use " + argv[0] + " <image> <new width> <new height> <rescaled file>"

    import cv2
    W, H = int(argv[2]), int(argv[3])
    SRC = cv2.imread(argv[1], cv2.IMREAD_GRAYSCALE)
    cv2.imwrite(argv[4], cv2.resize(SRC, (W, H), interpolation=cv2.INTER_NEAREST))
