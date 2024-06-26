

## Discussion Question 1 (10 Points): Debugging practice!

``` 
If you replace the BTB with a simple pc + 4 address prediction, the processor still works, but it does not perform as well. If you replace it with a really bad predictor that predicts pc is the next instruction for each pc, it should still work but have even worse performance because each instruction would require redirection (unless the instruction loops back to itself). If you actually set the prediction to pc, you will get errors in the assembly tests; the first one will be from cache.riscv.vmh.

    What is the error you get?
    What is happening in the processor to cause that to happen?
    Why do not you get this error with PC+4 and BTB predictors?
    How would you fix it?

You do not actually have to fix this bug, just answer the questions. (Hint: look at the addr field of ExecInst structure.)
```

1. lw:

Cycle          5 ----------------------------------------------------
Fetch: PC = 00000208, inst = 0000a183, expanded = lw r 3 = [r 1 0x0]
Execute finds misprediction: PC = 00000208
Fetch: Mispredict, redirected by Execute

Cycle          6 ----------------------------------------------------
Fetch: PC = 00001000, inst = 00ff00ff, expanded = unsupport 0xff00ff
Execute: Kill instruction

Cycle          7 ----------------------------------------------------
Fetch: PC = 00001000, inst = 00ff00ff, expanded = unsupport 0xff00ff

ERROR: Executing unsupported instruction at pc: 00001000. Exiting

2. sw:

Cycle          9 ----------------------------------------------------
Fetch: PC = 00000210, inst = 0020a023, expanded = sw [r 1 0x0] = r 2

Cycle         10 ----------------------------------------------------
Fetch: PC = 00000210, inst = 0020a023, expanded = sw [r 1 0x0] = r 2
Execute finds misprediction: PC = 00000210
Fetch: Mispredict, redirected by Execute

Cycle         11 ----------------------------------------------------
Fetch: PC = 00001000, inst = deadbeef, expanded = jal r29 0xfffdb5ea
Execute: Kill instruction

Cycle         12 ----------------------------------------------------
Fetch: PC = 00001000, inst = deadbeef, expanded = jal r29 0xfffdb5ea
Execute finds misprediction: PC = 00001000
Fetch: Mispredict, redirected by Execute

Cycle         13 ----------------------------------------------------
Fetch: PC = fffdc5ea, inst = 00000000, expanded = unsupport 0x0
Execute: Kill instruction

Cycle         14 ----------------------------------------------------
Fetch: PC = fffdc5ea, inst = 00000000, expanded = unsupport 0x0

ERROR: Executing unsupported instruction at pc: fffdc5ea. Exiting

3. cache:

Cycle          6 ----------------------------------------------------
Fetch: PC = 0000020c, inst = 0030a023, expanded = sw [r 1 0x0] = r 3

Cycle          7 ----------------------------------------------------
Fetch: PC = 0000020c, inst = 0030a023, expanded = sw [r 1 0x0] = r 3
Execute finds misprediction: PC = 0000020c
Fetch: Mispredict, redirected by Execute

Cycle          8 ----------------------------------------------------
Fetch: PC = 00004000, inst = 00000000, expanded = unsupport 0x0
Execute: Kill instruction

Cycle          9 ----------------------------------------------------
Fetch: PC = 00004000, inst = 00000000, expanded = unsupport 0x0
ERROR: Executing unsupported instruction at pc: 00004000. Exiting

Exec.bsv代码中
    eInst.addr = (dInst.iType == Ld || dInst.iType == St) ? aluRes : brAddr;

当指令为load和store时，eInst.addr的结果为aluRes，而不是brAddr。
当Fetch到的指令是lw或sw时，预测pc仍为当前pc必然会预测出错，因此nextPc会通过以下逻辑Redirect回IFU。
``` verilog
if(eInst.mispredict) begin //no btb update?
				$display("Execute finds misprediction: PC = %x", f2e.pc);
				exeRedirect[0] <= Valid (ExeRedirect {
					pc: f2e.pc,
					nextPc: eInst.addr // Hint for discussion 1: check this line
				});
			end
```
这时eInst.addr大概率不是正确的pc，因此会出错

通过预测PC+4 和 BTB predictors预测PC下一条指令时，
lw和sw下一条指令始终是PC+4，预测不会出错，不需要将eInst.addr的值Redirect回IFU，BTB predictors也不会预测出错，因此不会出现问题。

fix it: 
``` verilog
if(eInst.mispredict) begin
		$display("Execute finds misprediction: PC = %x", f2e.pc);
		exeRedirect[0] <= Valid (ExeRedirect {
			pc: f2e.pc,
			// nextPc: (eInst.iType == Br || eInst.iType == J || eInst.iType == Jr) ? eInst.addr : f2e.pc + 4
            nextPc: ((eInst.iType == St || eInst.iType == Ld) ? f2e.pc + 4 : eInst.addr )
		});
	end
	else begin
		$display("Execute: PC = %x", f2e.pc);
	end
```
在指令为lw和sw时，nextPc修正为f2e.pc + 4，其它情况可以保持nextPc为eInst.addr。

## Exercise 1 (20 Points): 

> Starting with the two-stage implementation in TwoStage.bsv, replace each memory with FPGAMemory and extend the pipeline into a six-stage pipeline in SixStage.bsv.In simulation, benchmark qsort may take longer time (21 seconds on TA's desktop, and it may take even longer on the vlsifarm machines).


## Discussion Question 2 (5 Points): 
### What evidence do you have that all pipeline stages can fire in the same cycle?

look at simple.log, all pipeline stages can fire in the same cycle
Cycle          4 ----------------------------------------------------
Fetch: pc = 00000214 predPc 00000218
Decode: PC = 00000210, inst = 00000013, expanded = addi r 0 = r 0 0x0
RegFile: PC = 0000020c, rVal1 = 00000000, rVal2 = 00000000, csrVal = 00000000
Exec: PC = 00000208 
Mem: PC = 00000204
WriteBack: PC = 00000200, data = 00000000

## Discussion Question 3 (5 Points): 
### In your six-stage pipelined processor, how many cycles does it take to correct a mispredicted instruction?

find mispredict happens in exec stage, it will take 3 cycles to correct the mispredicted instruction.
For Example, in j.log
Cycle 0, Fetch pc 00000204, predPc 00000208, but in exec stage, find mispredicted, actual nextPc is 0000020c
In Cycle 4, the correct pc 0000020c will be feched.
If not mispredicted, the actual nextPc will be fetch in Cycle 1.
``` 
Cycle          0 ----------------------------------------------------
Fetch: pc = 00000204 predPc 00000208
Decode: PC = 00000200, inst = 00200e13, expanded = addi r28 = r 0 0x2

Cycle          1 ----------------------------------------------------
Fetch: pc = 00000208 predPc 0000020c
Decode: PC = 00000204, inst = 0080006f, expanded = jal r 0 0x8
RegFile: PC = 00000200, rVal1 = 00000000, rVal2 = 00000000, csrVal = 00000000

Cycle          2 ----------------------------------------------------
Fetch: pc = 0000020c predPc 00000210
Decode: PC = 00000208, inst = 0380006f, expanded = jal r 0 0x38
RegFile: PC = 00000204, rVal1 = 00000000, rVal2 = 00000000, csrVal = 00000000
Exec: PC = 00000200 

Cycle          3 ----------------------------------------------------
Fetch: pc = 00000210 predPc 00000214
Decode: PC = 0000020c, inst = 00100093, expanded = addi r 1 = r 0 0x1
RegFile: PC = 00000208, rVal1 = 00000000, rVal2 = 00000000, csrVal = 00000000
Mis-predicted branch at pc 00000204, predicted 00000208, actual 0000020c
Exec: PC = 00000204 
Mem: PC = 00000200

Cycle          4 ----------------------------------------------------
Fetch: pc = 0000020c predPc 00000210
Decode: PC = 00000210, inst = 0140006f, expanded = jal r 0 0x14
RegFile: PC = 0000020c, rVal1 = 00000000, rVal2 = 00000000, csrVal = 00000000
Exec: PC = 00000208, epoch mismatch
Mem: PC = 00000204
WriteBack: PC = 00000200, data = 00000002
```

## Discussion Question 4 (5 Points): 
### If an instruction depends on the result of the instruction immediately before it in the pipeline, how many cycles is that instruction stalled?
If instruction N will update rx, but the instruction N+1 will immediately use rx as src, the operation will be stalled.
because in regfile fetch stage, rx will be insert to scoreboard and will be remove in writeback stage.
so 3 cycles the instruction will be stalled.

For example: in addi.log
pc 00000200 is the addi instruction, it will insert r into scoreboard at RegFile Fetch in Cycle 1.
In Cycle 2, the instruction in pc 00000204 is addi r 3, it will use r, but r is in scoreboard, so will stall at RegFile Fetch stage.
Until Cycle 4, the r will be remove frome scoreboard.
So In Cycle 5, the instruction in pc 00000204 will be continue exec.

``` 
Cycle          0 ----------------------------------------------------
Fetch: pc = 00000204 predPc 00000208
Decode: PC = 00000200, inst = 00000093, expanded = addi r 1 = r 0 0x0

Cycle          1 ----------------------------------------------------
Fetch: pc = 00000208 predPc 0000020c
Decode: PC = 00000204, inst = 00008193, expanded = addi r 3 = r 1 0x0
RegFile: PC = 00000200, rVal1 = 00000000, rVal2 = 00000000, csrVal = 00000000

Cycle          2 ----------------------------------------------------
Fetch: pc = 0000020c predPc 00000210
Decode: PC = 00000208, inst = 00000e93, expanded = addi r29 = r 0 0x0
RegFile: PC = 00000204, stall
Exec: PC = 00000200 

Cycle          3 ----------------------------------------------------
Fetch: pc = 00000210 predPc 00000214
Decode: PC = 0000020c, inst = 00200e13, expanded = addi r28 = r 0 0x2
RegFile: PC = 00000204, stall
Mem: PC = 00000200

Cycle          4 ----------------------------------------------------
Fetch: pc = 00000214 predPc 00000218
Decode: PC = 00000210, inst = 27d19e63, expanded = bne r 3 r29 0x27c
RegFile: PC = 00000204, stall
WriteBack: PC = 00000200, data = 00000000

Cycle          5 ----------------------------------------------------
Fetch: pc = 00000218 predPc 0000021c
Decode: PC = 00000214, inst = 00100093, expanded = addi r 1 = r 0 0x1
RegFile: PC = 00000204, rVal1 = 00000000, rVal2 = 00000000, csrVal = 00000000

```

## Discussion Question 5 (5 Points): 
### What IPC do you get for each benchmark?

| Benchmark |	Insts |	Cycles | IPC |
| - | - | - | - |
median	|	4243	| 15403	    |0.275
multiply|	20893	| 38538	    |0.542
qsort	|	123496	| 419245	|0.295
towers	|	4168	| 6950	    |0.600
vvadd	|	2408	| 3637	    |0.662

## Exercise 2 (20 Points): 
> Implement a branch history table in Bht.bsv that uses a parameterizable number of bits as an index into the table.


## Discussion Question 6 (10 Points): Planning!

``` 
One of the hardest things about this lab is properly training and integrating the BHT into the pipeline. There are many mistakes that can be made while still seeing decent results. By having a good plan based on the fundamentals of direction prediction, you will avoid many of those mistakes.

For this discussion question, state your plan for integrating the BHT into the pipeline. The following questions should help guide you:

    Where will the BHT be positioned in the pipeline?
    What pipeline stage performs lookups into the BHT?
    In which pipeline stage will the BHT prediction be used?
    Will the BHT prediction need to be passed between pipeline stages? 

    How to redirect PC using BHT prediction?
    Do you need to add a new epoch?
    How to handle the redirect messages?
    Do you need to change anything to the current instruction and its data structures if redirecting? 

    How will you train the BHT?
    Which stage produces training data for the BHT?
    Which stage will use the interface method to train the BHT?
    How to send training data?
    For which instructions will you train the BHT? 

    How will you know if your BHT works? 
```
BHT 预测在 decode stage, BHT 更新在 exec stage。
Decode Stage.
Fetch Stage.
Yes, 执行阶段得到的nextPc总是正确的，BHT prediction need to be passed until exec stage, the prediction will be compared with the correct pc.

Adding a dEpoch Reg. using Ehr.Decode Stage通过_write1 更新pcReg.
优先级最高的重定向信息来自执行阶段，其次来自译码阶段。
译码阶段 `f2d.dEpoch != dEpoch || f2d.eEpoch != eEpoch` 时会stall，丢弃错误的指令。

根据执行阶段的正确nextPc与预测的pc之间的关系训练BHT。
执行阶段会用到 `bht.update(r2e.pc, eInst.brTaken)`

All assemble and benchmark tests pass and most tests' IPC increase.

## Exercise 3 (20 Points): 
> Integrate a 256-entry (8-bit index) BHT into the six-stage pipeline from SixStage.bsv, and put the results in SixStageBHT.bsv.

## Discussion Question 7 (5 Points): 
### How much improvement do you see in the bpred_bht.riscv.vmh test over the processor in SixStage.bsv?

5979 -> 3174 (-46.9%)

## Exercise 4 (10 Points):

> Move address calculation for JAL up to the decode stage and use the edirect logic used by the BHT to redirect for these instructions too.


## Discussion Question 8 (5 Points):

```
How much improvement do you see in the bpred_j.riscv.vmh and bpred_j_noloop.riscv.vmh tests over the processor in SixStage.bsv?
```
bpred_j.riscv.vmh
2224 -> 2170 (2.43%)

bpred_j_noloop.riscv.vmh
235 -> 141 (-40%)
j_noloop has a big reduction due to BTB will mispredict without BHT.

## Discussion Question 9 (5 Points): 
### What IPC do you get for each benchmark? How much improvement is this over the original six-stage pipeline?


|Benchmark|	Insts	|Cycles(BHT)|     IPC(BHT)|    Cycles(BTB)|	    IPC(BHT)|	Improvement |
| - | - |- | - | - | - | - |
median	|	4243	|    10989  |	    0.386 |       15403   |        0.275|          +40.36%
multiply|	20893	|    36025  |     0.580   |     38538     |      0.542  |        +7.01%
qsort	|	123496	|    285007 |     0.433   |     41924     |      0.295  |        +46.8%
towers	|	4168	|    6651	|    0.627    |    6950	      |   0.600     |     +4.5%
vvadd	|	2408	|    3633   |     0.663   |     3637	  |       0.662 |         +0.15%

## Exercise 5 (10 Bonus Points)

>  JALR instructions have known target addresses in the register fetch stage. 
Add a redirection path for JALR instructions in the register fetch stage and put the results in SixStageBonus.bsv. 
The bpred_ras.riscv.vmh test should give slightly better results with this improvement.

> Most JALR instructions found in programs are used as returns from function calls.
This means the target address for such a return was written into the return address register x1 (also called ra) 
by a previous JAL or JALR instruction that initiates the function call.


-- assembly test: bpred_ras -- 
Insts   :283
Cycles(BTB  )   : 1562
Cycles(BHT  )   : 1277
Cycles(BONUS)   : 840

## Exercise 6 (10 Bonus Points):


> Implement a return address stack and integrate it into the Decode stage of your processor (SixStageBonus.bsv).An 8 element stack should be enough. If the stack fills up, you could simply discard the oldest data. The bpred_ras.riscv.vmh test should give an even better result with this improvement. If you implemented the RAS in a separate BSV file, make sure to add it to the git repository for grading.

## Discussion Question 10 (Optional): 
> How long did it take you to complete this lab?
about 20H.
