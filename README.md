# MIT_6.175_6.375_Lab
MIT 6.004 6.175 6.375 course, notes, Lab and Project. digital design and computer architecture.

## 6.175_Lab1

Exercise 1 (4 Points): Using the and, or, and not gates, re-implement the function multiplexer1 in Multiplexer.bsv. How many gates are needed? (The required functions, called and1, or1 and not1, respectively, are provided in Multiplexers.bsv.)

Exercise 2 (1 Point): Complete the implementation of the function multiplexer5 in Multiplexer.bsv using for loops and multiplexer1.

Exercise 3 (2 Points): Complete the definition of the function multiplexer_n. Verify that this function is correct by replacing the original definition of multiplexer5 to only have: return multiplexer_n(sel, a, b);. This redefinition allows the test benches to test your new implementation without modification.

Exercise 4 (2 Points): Complete the code for add4 by using a for loop to properly connect all the uses of fa_sum and fa_carry.

Exercise 5 (5 Points): Complete the code for the carry-select adder in the module mkCSAdder

Write your answers to these questions in the text file discussion.txt provided with the initial lab code.

1. How many gates does your one-bit multiplexer use? The 5-bit multiplexer? Write down a formula for the number of gates in an N-bit multiplexer. (2 Points)
2. Assume a single full adder requires 5 gates. How many gates does the 8-bit ripple-carry adder require? How many gates does the 8-bit carry-select adder require? (2 Points)
3. Assume a single full adder requires A time unit to compute its outputs once all its inputs are valid and a mux requires M time unit to compute its output. In terms of A and M, how long does the 8-bit ripple-carry adder take? How long does the 8-bit carry-select adder take? (2 Points)
4. Optional: How long did you take to work on this lab?