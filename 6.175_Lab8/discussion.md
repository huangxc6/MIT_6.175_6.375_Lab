## Exercise 1 (40 Points): Implement exceptions as described above on the processor in ExcepProc.bsv. You can build the processor by running
``` 
make build.bluesim VPROC=EXCEP

. We have provided the following scripts to run the test programs in simulation:

    run_asm.sh: run assembly tests in machine mode (without exceptions).
    run_bmarks.sh: run benchmarks in machine mode (without exceptions).
    run_excep.sh: run benchmarks in user mode (with exceptions).
    run_permit.sh: run the permission program in user mode.
```
> Your processor should pass all the tests in the first three scripts (run_asm.sh, run_bmarks.sh, and run_excep.sh), but should report an error and terminate on the last script (run_permit.sh). Note that after you see the error message outputted when running run_permit.sh, the testbench is still running, so you may need to hit Ctrl-C to terminate it.

## Discussion Question 1 (10 Points): 
> In the spirit of the upcoming Thanksgiving holiday, list some reasons you are thankful you only have to do this lab on a one-cycle processor. To get you started: what new hazards would exceptions introduce if you were working on a pipelined implementation?

A synchronous interrupt is casused by a particular instruction, and behave like a control hazard, i.e., the PC has to be redirected and instructions that follow in the nprmal flow that are already in the pipeline have to be dropped, just like wrong-path instructions after misprediction.

## Discussion Question 2 (Optional): How long did it take for you to finish this lab?

4H.

