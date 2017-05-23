from random import uniform
from sys import argv

if __name__ == "__main__":
    assert len(argv) == 2, \
        """Wrong nuber of arguments.
        Prints a random number drawn from a normal distribution rounded to 1/100.
        Use """ + argv[0] + """ <max>"""
    
    print round(uniform(0, float(argv[1])), 2)
