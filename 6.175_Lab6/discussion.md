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
fix it: 在
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
指令为lw和sw时，nextPc修正为f2e.pc + 4，其它情况可以保持nextPc为eInst.addr。

