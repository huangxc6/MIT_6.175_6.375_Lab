// SixStage.bsv
//
// This is a six stage pipelined implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import Btb::*;
import Scoreboard::*;
import FPGAMemory::*;

typedef struct {
    Addr pc;
    Addr predPc;
    Bool epoch;
} Fetch2Decode deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool epoch;
} Decode2RegFile deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool epoch;
} RegFile2Exec deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Maybe#(ExecInst) eInst;
} Exec2Mem deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Maybe#(ExecInst) eInst;
} Mem2WriteBack deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr nextPc;
} ExeRedirect deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    Ehr#(2, Addr)   pcReg <- mkEhr(?);
    RFile           rf    <- mkRFile;
    Scoreboard#(6)  sb    <- mkCFScoreboard;
    FPGAMemory      iMem  <- mkFPGAMemory;
    FPGAMemory      dMem  <- mkFPGAMemory;
    CsrFile         csrf  <- mkCsrFile;
    Btb#(6)         btb   <- mkBtb;  // 6-bit branch predictor

    Reg#(Bool)      exeEpoch <- mkReg(False);
    Fifo#(6, Fetch2Decode)      f2dFifo  <- mkCFFifo; // 6 is the size of the FIFO
    Fifo#(6, Decode2RegFile)    d2rfFifo <- mkCFFifo;
    Fifo#(6, RegFile2Exec)      rf2eFifo <- mkCFFifo;
    Fifo#(6, Exec2Mem)          e2mFifo  <- mkCFFifo;
    Fifo#(6, Mem2WriteBack)     m2wFifo  <- mkCFFifo; 

    Bool memReady = iMem.init.done && dMem.init.done;
    rule test (!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    // Fetch stage
    rule doFetch(csrf.started);
        // Fetch the instruction from the instruction memory
        iMem.req(MemReq { op: Ld, addr: pcReg[0], data: ? });
        Addr predPc = btb.predPc(pcReg[0]);

        // Put the instruction into the FIFO
        Fetch2Decode f2d = Fetch2Decode { 
            pc: pcReg[0], 
            predPc: predPc,
            epoch: exeEpoch
        };
        f2dFifo.enq(f2d);
        pcReg[0] <= predPc;
        
        $display("Fetch: pc = %x predPc %x", f2d.pc, f2d.predPc);
    endrule

    // Decode stage
    rule doDecode(csrf.started);
        f2dFifo.deq;
        let f2d = f2dFifo.first;
        let inst <- iMem.resp;

        // Decode the instruction
        DecodedInst dInst = decode(inst);

        // Put the decoded instruction into the FIFO
        Decode2RegFile d2rf = Decode2RegFile {
            pc: f2d.pc,
            predPc: f2d.predPc,
            dInst: dInst,
            epoch: f2d.epoch
        };
        d2rfFifo.enq(d2rf);
        $display("Decode: PC = %x, inst = %x, expanded = ", f2d.pc, inst, showInst(inst)); 
    endrule

    // Register file stage
    rule doRegFile(csrf.started);
        let d2rf = d2rfFifo.first;
        let dInst = d2rf.dInst;

        // Read the register file
        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        // Put the results into the FIFO
        RegFile2Exec rf2e = RegFile2Exec {
            pc: d2rf.pc,
            predPc: d2rf.predPc,
            dInst: dInst,
            rVal1: rVal1,
            rVal2: rVal2,
            csrVal: csrVal,
            epoch: d2rf.epoch
        };
        // Check for data hazards
        if (!sb.search1(dInst.src1) && !sb.search2(dInst.src2)) begin
            sb.insert(dInst.dst);
            d2rfFifo.deq;
            rf2eFifo.enq(rf2e);
            $display("RegFile: PC = %x, rVal1 = %x, rVal2 = %x, csrVal = %x", d2rf.pc, rVal1, rVal2, csrVal);
        end else begin
            $display("RegFile: PC = %x, stall", d2rf.pc);
        end
    endrule

    // Execute stage
    rule doExec(csrf.started);
        let rf2e = rf2eFifo.first;
        Maybe#(ExecInst) _eInst = Invalid;

        if (rf2e.epoch != exeEpoch) begin
            $display("Exec: PC = %x, epoch mismatch", rf2e.pc);
        end else begin
        // Execute the instruction
            ExecInst eInst = exec(rf2e.dInst, rf2e.rVal1, rf2e.rVal2, rf2e.pc,rf2e.predPc, rf2e.csrVal);
            _eInst = Valid(eInst);
            // check unsupported instruction at commit time. Exiting
            if (eInst.iType == Unsupported) begin
                $fwrite(stderr,"ERROR: Executing unsupported instruction at pc: %x. Exiting\n", rf2e.pc);
                $finish;
                end
        
            if (eInst.iType == J || eInst.iType == Jr || eInst.iType == Br) begin
                // update the branch predictor
                btb.update(rf2e.pc, eInst.addr);
            end
            if (eInst.mispredict) begin
                $display("Mis-predicted branch at pc %x, predicted %x, actual %x", rf2e.pc, rf2e.predPc, eInst.addr);
                pcReg[1] <= eInst.addr;
                exeEpoch <= !exeEpoch;
                end
            $display("Exec: PC = %x ", rf2e.pc);
            end

        rf2eFifo.deq;

        // Put the results into the FIFO
        let e2m = Exec2Mem {
            pc: rf2e.pc,
            eInst: _eInst
        };  
        e2mFifo.enq(e2m);
        
    endrule

    // Memory stage
    rule doMem(csrf.started);
        let e2m = e2mFifo.first;

        if (isValid(e2m.eInst)) begin
            let eInst = fromMaybe(?, e2m.eInst);
            if (eInst.iType == Ld) begin
                // Execute the memory operation
                dMem.req(MemReq {
                    op: Ld,
                    addr: eInst.addr,
                    data: ? 
                });
            end else if (eInst.iType == St) begin
                // Execute the memory operation
                dMem.req(MemReq {
                    op: St,
                    addr: eInst.addr,
                    data: eInst.data
                });
            end
            $display("Mem: PC = %x", e2m.pc);
        end else begin
            $display("Mem: PC = %x, epoch mismatch", e2m.pc);
        end

        e2mFifo.deq;
        let m2w = Mem2WriteBack {
            pc: e2m.pc,
            eInst: e2m.eInst
        };
        m2wFifo.enq(m2w);
    endrule

    // Writeback stage
    rule doWriteBack(csrf.started);
        let m2w = m2wFifo.first;

        if (isValid(m2w.eInst)) begin
            let eInst = fromMaybe(?, m2w.eInst);
            if (eInst.iType == Ld) begin
                // Get the result from the memory operation
                eInst.data <- dMem.resp;
                end
                // Write the result to the register file
            if (isValid(eInst.dst)) begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
                end
                csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
                $display("WriteBack: PC = %x, data = %x", m2w.pc, eInst.data);
        end else begin
            $display("WriteBack: PC = %x, epoch mismatch", m2w.pc);
        end

        m2wFifo.deq;
        sb.remove;
    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
		csrf.start(0); // only 1 core, id = 0
		$display("Start at pc 200\n");
		$fflush(stdout);
        pcReg[0] <= startpc;
    endmethod

	interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
        
endmodule
