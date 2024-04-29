// TwoStageBTB.bsv
//
// This is a two stage pipelined implementation of the SMIPS processor with a BTB.

import FIFOF::*;
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

typedef struct {
    DecodedInst dInst;
    Addr        pc;
} F2E deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    // Reg#(Addr) pc <- mkRegU;
    Ehr#(2, Addr) pc <- mkEhr(0);
    RFile      rf <- mkRFile;
    IMemory  iMem <- mkIMemory;
    DMemory  dMem <- mkDMemory;
    CsrFile  csrf <- mkCsrFile;
    Btb#(6) btb <- mkBtb;
    // Reg #(Bit #(32)) cycles <- mkReg(0);

    Bool memReady = iMem.init.done() && dMem.init.done();

    // TODO: Complete the implementation of this processor

    FIFOF#(F2E) f2e <- mkFIFOF;

    rule test(!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    rule doFetch(csrf.started);
        let inst = iMem.req(pc[0]);
        let dInst = decode(inst);
        let new_pc = btb.predPc(pc[0]);
        pc[0] <= new_pc;
        f2e.enq(F2E{dInst: dInst, pc: pc[0]});

        // trace 
        $display("Fetch: pc = %h, inst = %h, expanded = ", pc[0], inst, showInst(inst));
        $fflush(stdout);
    endrule

    rule doExecute(csrf.started);
        let x = f2e.first;
        let dInst = x.dInst;
        let x_pc = x.pc;
        let ppc = btb.predPc(x_pc);

        let rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        let rVal2 = rf.rd2(fromMaybe(?, dInst.src2));   
        let csrVal = csrf.rd(fromMaybe(?, dInst.csr));
        let eInst = exec(dInst, rVal1, rVal2, x_pc, ppc, csrVal);

        if (eInst.iType == Br || eInst.iType == J || eInst.iType == Jr) begin
            btb.update(x_pc, eInst.addr);
        end

        // memory
        if (eInst.iType == Ld) begin
            eInst.data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
        end else if (eInst.iType == St) begin
            let d <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
        end

        // write back
        if (isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), eInst.data);
        end

        // csr
        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
        
        if (eInst.mispredict) begin
            pc[1] <= eInst.addr;
            f2e.clear;
        end else begin
            f2e.deq;
        end

        // unsupport
        if (eInst.iType == Unsupported) begin
            $fwrite(stderr, "Unsupported instruction at pc: %x. Exitting...\n", x_pc);
            $finish;
        end 
    endrule

    // rule forceStop (csrf.started);
    //     cycles <= cycles + 1;
    //     if (cycles == 100000) begin
    //         $display("force stop: cycle = %d", cycles);
    //         $finish;
    //     end
    // endrule


    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0);
        pc[0] <= startpc;
    endmethod

    interface MemInit iMemInit = iMem.init;
    interface MemInit dMemInit = dMem.init;
endmodule

