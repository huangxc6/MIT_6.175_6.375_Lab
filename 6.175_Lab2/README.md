## Exercise 1 (2 Points): In TestBench.bsv, write a test bench mkTbSignedVsUnsigned that tests if multiply_signed produces the same output as multiply_unsigned. Compile this test bench as described above and run it. (That is, run

$ make SignedVsUnsigned.tb

and then

$ ./simSignedVsUnsigned

)

``` shell
Error: "./Multipliers.bsv", line 45, column 17: (P0136)
  Empty () for rule condition forbidden: for true condition, remove () in rule
  "mulStep"

注释掉

huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab2$ ./simDumb
PASSED case 1
    if signed: 105 * 115 test function gave 12075
    if unsigned: 105 * 115 test function gave 12075
PASSED case 2
    if signed: 81 * -1 test function gave 20655
    if unsigned: 81 * 255 test function gave 20655
PASSED case 3
    if signed: 74 * -20 test function gave 17464
    if unsigned: 74 * 236 test function gave 17464
PASSED case 4
    if signed: 41 * -51 test function gave 8405
    if unsigned: 41 * 205 test function gave 8405
PASSED case 5
    if signed: -70 * -85 test function gave 31806
    if unsigned: 186 * 171 test function gave 31806




huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab2$ ./simSignedVsUnsigned
PASSED case 1
    if signed: 105 * 115 test function gave 12075
    if unsigned: 105 * 115 test function gave 12075
FAILED:
    if signed: 81 * -1 test function gave 20655 instead of -81
    if unsigned: 81 * 255 test function gave 20655 instead of 65455
```

### Discussion Question 2 (2 Points): In mkTBDumb excluding the line

function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );

and modifying the rest of the module to have

(* synthesize *)
module mkTbDumb();
    Empty tb <- mkTbMulFunction(multiply_unsigned, multiply_unsigned, True);
    return tb;
endmodule

will result in a compilation error. What is that error? How does the original code fix the compilation error? You could also fix the error by having two function definitions as shown below.

(* synthesize *)
module mkTbDumb();
    function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
    function Bit#(16) ref_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
    Empty tb <- mkTbMulFunction(test_function, ref_function, True);
    return tb;
endmodule

Why is two function definitions not necessary? (i.e. why can the second operand to mkTbMulFunction have variables in its type?) Hint: Look at the types of the operands of mkTbMulFunction in TestBenchTemplates.bsv.

``` shell

  Error: "TestBench.bsv", line 8, column 17: (T0035)
  Bit vector of unknown size introduced near this location.
  Please remove unnecessary extensions, truncations and concatenations and/or
  provide more type information to resolve this ambiguity.
make: *** [Makefile:5: compile] Error 1

the compiler does not know the input or output bit vector size of multiply_unsigned. Including the line allows for the compiler to infer that the multiply_unsigned's are compared with input types of Bit#(8) and output types of Bit#(16). Only one multiply_unsigned needs to have its inputs defined because the compiler can infer for the other.

The compiler doesn't know the Bit vector size of multiply_unsigned, it can infer it by defining a size.

```
## Exercise 2 (3 Points): Fill in the code for multiply_by_adding so it calculates the product of a and b using repeated addition in a single clock cycle. (You will verify the correctness of your multiplier in Exercise 3.) If you need an adder to produce an (n+1)-bit output from two n-bit operands, follow the model of multiply_unsigned and multiply_signed and extend the operands to (n+1)-bit before adding.

## Exercise 3 (1 Point): Fill in the test bench mkTbEx3 in TestBench.bsv to test the functionality of multiply_by_adding. Compile it with

$ make Ex3.tb

and run it with

$ ./simEx3

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab2$ ./simEx3
PASSED case 1
    if signed: 105 * 115 test function gave 12075
    if unsigned: 105 * 115 test function gave 12075
PASSED case 2
    if signed: 81 * -1 test function gave 20655
    if unsigned: 81 * 255 test function gave 20655
PASSED case 3
    if signed: 74 * -20 test function gave 17464
    if unsigned: 74 * 236 test function gave 17464
PASSED case 4
    if signed: 41 * -51 test function gave 8405
    if unsigned: 41 * 205 test function gave 8405

```

### Discussion Question 3 (1 Point): Is your implementation of multiply_by_adding a signed multiplier or an unsigned multiplier? (Note: if it does not match either multiply_signed or multiply_unsigned, it is wrong).

unsigned multiplier

## Exercise 4 (4 Points): Fill in the code for the module mkFoldedMultiplier to implement a folded repeated addition multiplier.

Can you implement it without using a variable-shift bit shifter? Without using dynamic bit selection? (In other words, can you avoid shifting or bit selection by a value stored in a register?)

## Exercise 5 (1 Points): Fill in the test bench mkTbEx5 to test the functionality of mkFoldedMultiplier against multiply_by_adding. They should produce the same outputs if you implemented mkFoldedMultiplier correctly. To run these, run

$ make Ex5.tb
$ ./simEx5

注意mkTbMulModule传参为Multiplier和function

## Exercise 6 (4 Points): Fill in the implementation for a folded version of the Booth multiplication algorithm in the module mkBooth: This module uses a parameterized input size n; your implementation will be expected to work for all n >= 2.

## Exercise 7 (1 Point): Fill in the test benches mkTbEx7a and mkTbEx7b for your Booth multiplier to test different bit widths of your choice. You can test them with:

$ make Ex7a.tb
$ ./simEx7a

and

$ make Ex7b.tb
$ ./simEx7b

### Discussion Question 4 (1 Point): Fill in above table in discussion.txt. None of the Radix-4 Booth encodings should have more than one non-zero symbol in them.

## Exercise 8 (2 Points): Fill in the implementation for a radix-4 Booth multiplier in the module mkBoothRadix4. This module uses a parameterized input size n; your implementation will be expected to work for all even n >= 2.

## Exercise 9 (1 Point): Fill in test benches mkTbEx9a and mkTbEx9b for your radix-4 Booth multiplier to test different even bit widths of your choice. You can test them with

$ make Ex9a.tb
$ ./simEx9a

and

$ make Ex9b.tb
$ ./simEx9b

### Discussion Question 5 (1 Point): Now consider extending your Booth multiplier even further to a radix-8 Booth multiplier. This would be like doing 3 steps of the radix-2 Booth multiplier in a single step. Can all radix-8 Booth encodings be represented with only one non-zero symbol like the radix-4 Booth multiplier? Do you think it would still make sense to make a radix-8 Booth multiplier?

### Discussion Question 6 (Optional): How long did you take to work on this lab?



