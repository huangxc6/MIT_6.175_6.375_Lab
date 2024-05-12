// SixStage.bsv
//
// This is a six stage pipelined implementation with branch history table(BHT) of the RISC-V processor.

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
import Bht::*;

typedef struct {
    Addr pc;
    Addr predPc;
    Bool dEpoch;
    Bool rEpoch;
    Bool eEpoch;
} Fetch2Decode deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool rEpoch;
    Bool eEpoch;
} Decode2RegRead deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool eEpoch;
} RegRead2Exec deriving (Bits, Eq);

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
    Ehr#(4, Addr)   pcReg <- mkEhr(?);
    RFile           rf    <- mkRFile;
    Scoreboard#(6)  sb    <- mkCFScoreboard;
    FPGAMemory      iMem  <- mkFPGAMemory;
    FPGAMemory      dMem  <- mkFPGAMemory;
    CsrFile         csrf  <- mkCsrFile;
    Btb#(6)         btb   <- mkBtb;  // 6-bit branch predictor
    Bht#(8)         bht   <- mkBht;  // 8-bit branch history table

    Reg#(Bool)      eEpoch <- mkReg(False);
    Reg#(Bool)      rEpoch <- mkReg(False);
    Reg#(Bool)      dEpoch <- mkReg(False);
    Fifo#(6, Fetch2Decode)      f2dFifo  <- mkCFFifo; // 6 is the size of the FIFO
    Fifo#(6, Decode2RegRead)    d2rFifo <- mkCFFifo;
    Fifo#(6, RegRead2Exec)      r2eFifo <- mkCFFifo;
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
            dEpoch: dEpoch,
            rEpoch: rEpoch,
            eEpoch: eEpoch
        };
        f2dFifo.enq(f2d);
        pcReg[0] <= predPc;
        
        $display("[Fetch Stage]: pc = %x predPc %x", f2d.pc, f2d.predPc);
    endrule

    // Decode stage
    rule doDecode(csrf.started);
        f2dFifo.deq;
        let f2d = f2dFifo.first;
        let inst <- iMem.resp;

        // Decode the instruction
        if (f2d.dEpoch != dEpoch || f2d.eEpoch != eEpoch || f2d.rEpoch != rEpoch) begin
            $display("[Decode Stage]: PC = %x, epoch mismatch, expand = (killed)",f2d.pc, showInst(inst));
        end else begin
            DecodedInst dInst = decode(inst);
            let predPc = (dInst.iType == J || dInst.iType == Br) ? bht.ppcDP(f2d.pc, f2d.pc + fromMaybe(?, dInst.imm)) : f2d.predPc;

            if (f2d.predPc != predPc) begin
                dEpoch <= !dEpoch;
                pcReg[1] <= predPc;
                $display("Decode Predict: PC = %x, predicted = %x, bht_predicted = %x", f2d.pc, f2d.predPc, predPc);
            end
            // Put the decoded instruction into the FIFO
            Decode2RegRead d2r = Decode2RegRead {
                pc: f2d.pc,
                predPc: predPc,
                dInst: dInst,
                rEpoch: f2d.rEpoch,
                eEpoch: f2d.eEpoch
            };
            d2rFifo.enq(d2r);
            $display("[Decode Stage] PC = %x, inst = %x, expanded = ", f2d.pc, inst, showInst(inst));
        end 

    endrule

    // Register Read stage
    rule doRegRead(csrf.started);
        let d2r   = d2rFifo.first;
        let dInst = d2r.dInst;

        // Read the register file
        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        // Check for data hazards
        if (d2r.eEpoch != eEpoch || d2r.rEpoch != rEpoch) begin
            d2rFifo.deq; // kill the instruction if epoch mismatch if not stall
            $display("[RegRead Stage]: PC = %x, epoch mismatch, expand = (killed)", d2r.pc);
        end else
        if (!sb.search1(dInst.src1) && !sb.search2(dInst.src2)) begin
            // for better prediction
            let predPc = (dInst.iType == Jr) ? {truncateLSB(rVal1 + fromMaybe(?, dInst.imm)), 1'b0} : d2r.predPc;
            if (d2r.predPc != predPc) begin
                rEpoch <= !rEpoch;
                pcReg[2] <= predPc;
                $display("RegRead Predict: PC = %x, dStage_predicted = %x, Jr_predicted = %x", d2r.pc, d2r.predPc, predPc);
            end

            // Put the results into the FIFO
            RegRead2Exec r2e = RegRead2Exec {
                pc: d2r.pc,
                predPc: predPc,
                dInst: dInst,
                rVal1: rVal1,
                rVal2: rVal2,
                csrVal: csrVal,
                eEpoch: d2r.eEpoch
            };

            sb.insert(dInst.dst);
            d2rFifo.deq;
            r2eFifo.enq(r2e);
            $display("[RegRead Stage]: PC = %x, rVal1 = %x, rVal2 = %x, csrVal = %x", d2r.pc, rVal1, rVal2, csrVal);
        end else begin // stall
            $display("[RegRead Stage]: PC = %x, stall", d2r.pc);
        end
    endrule

    // Execute stage
    rule doExec(csrf.started);
        let r2e = r2eFifo.first;
        Maybe#(ExecInst) _eInst = Invalid;

        if (r2e.eEpoch != eEpoch) begin
            $display("[Exec Stage]: PC = %x, epoch mismatch, mispredict", r2e.pc);
        end else begin
        // Execute the instruction
            ExecInst eInst = exec(r2e.dInst, r2e.rVal1, r2e.rVal2, r2e.pc,r2e.predPc, r2e.csrVal);
            _eInst = Valid(eInst);
            // check unsupported instruction at commit time. Exiting
            if (eInst.iType == Unsupported) begin
                $fwrite(stderr,"ERROR: Executing unsupported instruction at pc: %x. Exiting\n", r2e.pc);
                $finish;
                end
        
            if (eInst.iType == J || eInst.iType == Br) begin
                // update the branch predictor
                bht.update(r2e.pc, eInst.brTaken);
            end
            if (eInst.mispredict) begin
                $display("Mis-predicted branch at pc %x, predicted %x, actual %x", r2e.pc, r2e.predPc, eInst.addr);
                pcReg[3] <= eInst.addr;
                eEpoch <= !eEpoch;
                btb.update(r2e.pc, eInst.addr);
                end
            $display("[Exec Stage]: PC = %x ", r2e.pc);
            end

        r2eFifo.deq;

        // Put the results into the FIFO
        let e2m = Exec2Mem {
            pc: r2e.pc,
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
            $display("[Mem Stage]: PC = %x", e2m.pc);
        end else begin
            $display("[Mem Stage]: PC = %x, epoch mismatch", e2m.pc);
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
                $display("c: PC = %x, data = %x", m2w.pc, eInst.data);
        end else begin
            $display("[WriteBack Stage]: PC = %x, epoch mismatch", m2w.pc);
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
