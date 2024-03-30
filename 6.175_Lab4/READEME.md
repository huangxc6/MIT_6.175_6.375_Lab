## Exercise 1 (5 points): Implement mkMyConflictFifo in MyFifo.bsv. You can build and run the functional testbench by running

$ make conflict
$ ./simConflictFunctional

There is no scheduling testbench for this module because enq and deq are expected to conflict.

### Discussion Question 1 (5 points): What registers are read from and written to in each of the interface methods? Remember that register reads performed in guards count.

### Discussion Question 2 (5 Points): Fill out the conflict matrix for mkMyConflictFifo. For simplicity, treat writes to the same register as conflicting (not just conflicting within a single rule).
