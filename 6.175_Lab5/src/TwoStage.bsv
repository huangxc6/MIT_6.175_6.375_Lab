// TwoStage.bsv
//
// This is a two stage pipelined implementation of the SMIPS processor.

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

typedef struct {
    DecodedInst dInst;
    Addr pc;
} F2E deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    // Reg#(Addr) pc <- mkRegU;
    Ehr#(2, Addr) pc <- mkEhr(0);
    RFile      rf <- mkRFile;
    IMemory  iMem <- mkIMemory;
    DMemory  dMem <- mkDMemory;
    CsrFile  csrf <- mkCsrFile;

    FIFOF #(F2E) f2e <- mkFIFOF;

    Bool memReady = iMem.init.done() && dMem.init.done();


    // TODO: Complete the implementation of this processor

    rule test(!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    rule doFetch(csrf.started);
        let inst = iMem.req(pc[0]);
        let dInst = decode(inst);
        f2e.enq(F2E {dInst: dInst, pc: pc[0]});

        // tace
        $display("Fetch: pc = %0d, inst = %0x, expand = %0x", pc[0], inst, showInst(inst));
        $fflush(stdout);
        
        pc[0] <= pc[0] + 4;
    endrule

    rule doExecute(csrf.started);
        let x       = f2e.first;
        let dInst   = x.dInst;
        let x_pc    = x.pc;
        let ppc     = x_pc + 4;

        let rVal1   = rf.rd1((fromMaybe(?, dInst.src1)));
        let rVal2   = rf.rd2((fromMaybe(?, dInst.src2)));
        let csrVal  = csrf.rd(fromMaybe(?, dInst.csr));
        let eInst   = exec(dInst, rVal1, rVal2, x_pc, ppc, csrVal);

        // memory access
        if (eInst.iType == Ld) begin
            eInst.data <- dMem.req(MemReq{op:Ld, addr:eInst.addr, data:?});
        end else if (eInst.iType == St) begin
            let d <- dMem.req(MemReq{op:St, addr:eInst.addr, data:eInst.data});
        end

        // write back
        if (isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), eInst.data);
        end
        // csr write
        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);

        if (eInst.mispredict) begin
            pc[1] <= eInst.addr;
            f2e.clear;
        end else begin
            f2e.deq;
        end

        // check unsupported instructions
        if (eInst.iType == Unsupported) begin
            $fwrite(stderr, "Unsupported instruction at pc: %0x.Exiting\n", x_pc);
            $finish;
        end

    endrule


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

