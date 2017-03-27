from random import gauss
from sys import argv

if __name__ == "__main__":
    assert len(argv) == 3, \
        """Wrong nuber of arguments.
        Prints a random number drawn from a normal distribution rounded to 1/100.
        Use """ + argv[0] + """ <mean> <std dev>"""
    
    print abs(round(gauss(float(argv[1]), float(argv[2])), 2))
