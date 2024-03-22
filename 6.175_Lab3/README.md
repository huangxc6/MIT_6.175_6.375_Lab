## Exercise 1 (5 Points): As a warmup, add guards to the enq, deq, and first methods of the two-element conflict-free FIFO included in Fifo.bsv.

## Exercise 2 (5 Points): In mkFftFolded, create a folded FFT implementation that makes use of just 16 butterflies overall. This implementation should finish the overall FFT algorithm (starting from dequeuing the input FIFO to enqueuing the output FIFO) in exactly 3 cycles.

The Makefile can be used to build simFold to test this implementation. Compile and run using

$ make fold
$ ./simFold

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab3$ ./simFold
PASSED
```

## Exercise 3 (5 Points): In mkFftInelasticPipeline, create an inelastic pipeline FFT implementation. This implementation should make use of 48 butterflies and 2 large registers, each carrying 64 complex numbers. The latency of this pipelined unit must also be exactly 3 cycles, though its throughput would be 1 FFT operation every cycle.

The Makefile can be used to build simInelastic to test this implementation. Compile and run using

$ make inelastic
$ ./simInelastic

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab3$ ./simInelastic
PASSED
```

