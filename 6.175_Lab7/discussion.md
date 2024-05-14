
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
