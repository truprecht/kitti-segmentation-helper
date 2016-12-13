#!python2
from sys import argv
from re import findall

if __name__ == "__main__":
    assert len(argv) == 2, \
        "Use " + argv[0] + " <test list>"
    
    with open(argv[1]) as testfile:
        for line in testfile:
            print " ".join(findall(r"""([^/\.]+).\w+(?: |$)""", line))