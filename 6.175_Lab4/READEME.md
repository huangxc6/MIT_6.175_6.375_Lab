## Exercise 1 (5 points): Implement mkMyConflictFifo in MyFifo.bsv. You can build and run the functional testbench by running

$ make conflict
$ ./simConflictFunctional

There is no scheduling testbench for this module because enq and deq are expected to conflict.

### Discussion Question 1 (5 points): What registers are read from and written to in each of the interface methods? Remember that register reads performed in guards count.

### Discussion Question 2 (5 Points): Fill out the conflict matrix for mkMyConflictFifo. For simplicity, treat writes to the same register as conflicting (not just conflicting within a single rule).

## Exercise 2 (10 Points): Implement mkMyPipelineFifo and mkMyBypassFifo in MyFifo.bsv using EHRs and the method mentioned above. You can build the functional and scheduling testbenches for the pipeline FIFO and the bypass FIFO by running

$ make pipeline

and

$ make bypass

respectively. If these compile with no scheduling warning, then the scheduling testbench passed and the two FIFOs have the expected scheduling behavior. To test their functionality against reference implementations you can run

$ ./simPipelineFunctional

and

$ ./simBypassFunctional

If you are having trouble implementing clear with the correct schedule and functionality, you can remove it from the tests temporarily by setting has_clear to false in the associated modules in TestBench.bsv.

``` shell
= cycle 1427 ====================
	Enqueued 163
= cycle 1428 ====================
	Enqueued 127
	Dequeued 163
= cycle 1429 ====================
	Enqueued 213
	Dequeued 127
= cycle 1430 ====================
	Enqueued 128
	Dequeued 213
= cycle 1431 ====================
	Enqueued 185
	Dequeued 128
= cycle 1432 ====================
	Enqueued 146
	Dequeued 185
= cycle 1433 ====================
	Finished Test
	Output count = 949
```