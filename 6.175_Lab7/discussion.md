
## Exercise 1 (10 Points): Implement a module mkTranslator in Cache.bsv that takes in some interface related to DDR3 memory (WideMem for example) and returns a Cache interface (see CacheTypes.bsv).

>This module should not do any caching, just translation from MemReq to requests to DDR3 (WideMemReq if using WideMem interfaces) and translation from responses from DDR3 (CacheLine if using WideMem interfaces) to MemResp. This will require some internal storage to keep track of which word you want from the cache line that comes back from main memory. Integrate mkTranslator into a six stage pipeline in the file WithoutCache.bsv (i.e. you should no longer use mkFPGAMemory here). You can build this processor by running
``` 
$ make build.bluesim VPROC=WITHOUTCACHE

and you can test this processor by running

$ ./run_asm.sh

and

$ ./run_bmarks.sh 
```

## Discussion Question 1 (5 Points): Record the results for ./run_bmarks.sh withoutcache. What IPC do you see for each benchmark?

| Benchmark |	Insts |	Cycles | IPC   |
| -     |     -     |     -     |   -  |
median	|	4242	| 48736	    |0.087
multiply|	20893	| 184223    |0.113
qsort	|	123496	| 1284159	|0.096
towers	|	4168	| 36150	    |0.115
vvadd	|	2408	| 19295	    |0.125

## Exercise 2 (20 Points): Implement a module mkCache to be a direct mapped cache that allocates on write misses and writes back only when a cache line is replaced.

> This module should take in a WideMem interface (or something similar) and expose a Cache interface. Use the typedefs in CacheTypes.bsv to size your cache and for the Cache interface definition. You can use either vectors of registers or register files to implement the arrays in the cache, but vectors of registers are easier to specify initial values. Incorporate this cache in the same pipeline from WithoutCache.bsv and save it in WithCache.bsv. You can build this processor by running

## Discussion Question 2 (5 Points): Record the results for ./run_bmarks.sh withcache. What IPC do you see for each benchmark?

| Benchmark |	Insts |	Cycles | IPC   |
| -     |     -     |     -     |   -  |
median	|	4243	| 10397	    |0.408
multiply|	20893	| 43265     |0.483
qsort	|	123496	| 287975	|0.429
towers	|	4171	| 21161	    |0.197
vvadd	|	2408	| 5306	    |0.454

## Exercise 3 (0 Points, but you should still totally do this): 
> Before synthesizing for an FPGA, let's try looking at a program that takes a long time to run in simulation. The program ./run_mandelbrot.sh runs a benchmark that prints a square image of the Mandelbrot set using 1's and 0's. Run this benchmark to see how slow it runs in real time. Please don't wait for this benchmark to finish, just kill it early using Ctrl-C.

``` shell
buffer /home/huangxc/MIT_course/MIT_6.175_6.375_Lab/6.175_Lab7/bluesim/bin/ubuntu.exe
111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111000011111111111111111111
111111111111111111111111111111111111000011111111111111111111
111111111111111111111111111111111111100111111111111111111111
111111111111111111111111111110010000000000011111111111111111
111111111111111111111111111111000000000000000001111111111111
111111111111111111111111111110000000000000000011111111111111
1111111111111111111111111111^Z
```