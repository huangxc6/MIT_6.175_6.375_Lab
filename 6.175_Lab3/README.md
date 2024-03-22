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

## Exercise 4 (10 Points):

In mkFftElasticPipeline, create an elastic pipeline FFT implementation. This implementation should make use of 48 butterflies and two large FIFOs. The stages between the FIFOs should be in their own rules that can fire independently. The latency of this pipelined unit must also be exactly 3 cycles, though its throughput would be 1 FFT operation every cycle.

The Makefile can be used to build simElastic to test this implementation. Compile and run using

$ make elastic
$ ./simElastic

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab3$ ./simElastic
PASSED
```

## Discussion Questions 1 and 2:
Assume you are given a black box module that performs a 10-stage algorithm. You can not look at its internal implementation, but you can test this module by giving it data and looking at the output of the module. You have been told that it is implemented as one of the structures covered in this lab, but you do not know which one.

    1. How can you tell whether the implementation of the module is a folded implementation or whether it is a pipeline implementation? (3 Points)

    If the throughput is one, then the implementation is pipelined; otherwise, it is folded.

    2. Once you know the module has a pipeline structure, how can you tell if it is inelastic or if it is elastic? (2 Points)

``` shell
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab3$ ./simSfol
PASSED
```



