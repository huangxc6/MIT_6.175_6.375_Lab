Exercise 1 (4 Points): Using the and, or, and not gates, re-implement the function multiplexer1 in Multiplexer.bsv. How many gates are needed? (The required functions, called and1, or1 and not1, respectively, are provided in Multiplexers.bsv.)


Exercise 2 (1 Point): Complete the implementation of the function multiplexer5 in Multiplexer.bsv using for loops and multiplexer1.

Check the correctness of the code by running the multiplexer testbench:

>> make mux
./simMux 

An alternate test bench can be used to see outputs from the unit by running:

>> make muxsimple
./simMuxSimple

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab1$ ./simMux
PASSED

huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab1$ ./simMuxSimple
Sel 0 from  0,  1 is  0
Sel 1 from  4,  7 is  7
Sel 0 from 31, 31 is 31
Sel 1 from  0, 31 is 31
Sel 0 from  0, 31 is  0
Sel 0 from  8,  0 is  8
Sel 1 from 11, 29 is 29
Sel 1 from 21, 22 is 22
PASSED
```

Exercise 3 (2 Points): Complete the definition of the function multiplexer_n. Verify that this function is correct by replacing the original definition of multiplexer5 to only have: return multiplexer_n(sel, a, b);. This redefinition allows the test benches to test your new implementation without modification.

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab1$ ./simMux
PASSED

huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab1$ ./simMuxSimple
Sel 0 from  0,  1 is  0
Sel 1 from  4,  7 is  7
Sel 0 from 31, 31 is 31
Sel 1 from  0, 31 is 31
Sel 0 from  0, 31 is  0
Sel 0 from  8,  0 is  8
Sel 1 from 11, 29 is 29
Sel 1 from 21, 22 is 22
PASSED
```

Exercise 4 (2 Points): Complete the code for add4 by using a for loop to properly connect all the uses of fa_sum and fa_carry.

```
    cout[4] uses uninitialized value
    Bit#(5) cout = 0;  initialize
```

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab1$ ./simRca
PASSED
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab1$ ./simRcaSimple
  1 +   1 =   2
  8 +   8 =  16
 63 +  27 =  90
102 +  92 = 194
177 + 202 = 379
128 + 128 = 256
255 +   1 = 256
255 + 255 = 510
PASSED
```

Exercise 5 (5 Points): Complete the code for the carry-select adder in the module mkCSAdder. Use Figure 3 as a guide for the required hardware and connections. This module can be tested by running the following:

use 5-bit Multiplexer

$ make csa
$ ./simCsa

An alternate test bench can be used to see outputs from the unit by running:

$ make csasimple
$ ./simCsaSimple

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab1$ ./simCsa
PASSED
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab1$ ./simCsaSimple
  1 +   1 =   2
  8 +   8 =  16
 63 +  27 =  90
102 +  92 = 194
177 + 202 = 379
128 + 128 = 256
255 +   1 = 256
255 + 255 = 510
PASSED
```

1. How many gates does your one-bit multiplexer use? The 5-bit multiplexer? Write down a formula for the number of gates in an N-bit multiplexer. (2 Points)
2. Assume a single full adder requires 5 gates. How many gates does the 8-bit ripple-carry adder require? How many gates does the 8-bit carry-select adder require? (2 Points)
3. Assume a single full adder requires A time unit to compute its outputs once all its inputs are valid and a mux requires M time unit to compute its output. In terms of A and M, how long does the 8-bit ripple-carry adder take? How long does the 8-bit carry-select adder take? (2 Points)
4. Optional: How long did you take to work on this lab?