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

### Discussion Question 3 (5 Points): Using your conflict matrix for mkMyConflictFifo, which conflicts do not match the conflict-free FIFO scheduling constraints shown above?

## Exercise 3 (30 Points): Implement mkMyCFFifo as described above without the clear method. You can build the functional and scheduling testbenches by running

$ make cfnc

If these compile with no scheduling warning, then the scheduling testbench passed and the enq and deq methods of the FIFO can be scheduled in any order. (It is fine to have a warning saying that rule m_maybe_clear has no action and will be removed.) You can run the functional testbench by running

$ ./simCFNCFunctional



## Exercise 4 (10 Points): Add the clear() method to mkMyCFFifo. It should come after all other interface methods, and it should come before the canonicalize rule. You can build the functional and scheduling testbenches by running

$ make cf

If these compile with no scheduling warning, then the scheduling testbench passed and the FIFO has the expected scheduling behavior. You can run the functional testbench by running

$ ./simCFFunctional

### Discussion Question 4 (5 Points): In your design of the clear() method, how did you force the scheduling constraint {enq, deq} < clear?

### Discussion Question 5 (Optional): How long did you take to work on this lab?

``` shell
= cycle 1468 ====================
	Enqueued 143
= cycle 1469 ====================
	Dequeued 143
	Enqueued 228
= cycle 1470 ====================
	Dequeued 228
	Enqueued 244
= cycle 1471 ====================
	Dequeued 244
	Enqueued 55
= cycle 1472 ====================
	Enqueued 206
= cycle 1473 ====================
	Dequeued 55
	Enqueued 221
= cycle 1474 ====================
	Dequeued 206
	Enqueued 115
= cycle 1475 ====================
	Finished Test
	Output count = 899
```