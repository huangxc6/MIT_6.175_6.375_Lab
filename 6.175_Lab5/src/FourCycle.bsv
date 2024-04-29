// FourCycle.bsv
//
// This is a four cycle implementation of the SMIPS processor.

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import RFile::*;
import DelayedMemory::*;
import MemInit::*;
import Decode::*;
import Exec::*;
import Cop::*;
import Vector::*;
import Fifo::*;
import Ehr::*;

typedef enum {Fetch, Decode, Execute, WriteBack} Stage deriving (Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr)     pc <- mkRegU;
    RFile          rf <- mkRFile;
    DelayedMemory imem <- mkDelayedMemory;
    DelayedMemory dmem <- mkDelayedMemory;
    CsrFile       csrf <- mkCsrFile;

    Bool memReady = imem.init.done() && dmem.init.done();

    // TODO: Complete the implementation of this processor

    Reg#(State)         stage <- mkReg(Fetch);
    Reg#(DecodedInst)   dInst <- mkRegU;
    Reg#(ExecInst)      eInst <- mkRegU;

    rule doFetch(csrf.started && stage == Fetch);
        imem.req(MemReq{op: Ld, addr: pc, data: ?});
        stage <= Decode;
    endrule

    rule doDecode(csrf.started && stage == Decode);
        let inst <- imem.resp;
        let _dInst = decode(inst);
        dInst <= _dInst;

        $display("pc : %h, inst : (%h), expanded : ",pc, inst, showInst(inst));
        $fflush(stdout); 

        stage <= Execute;
    endrule

    rule doExecute(csrf.started && stage == Execute);
        let _dInst = dInst;
        // Register file read
        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        // Execute
        let _eInst = exec(_dInst, rVal1, rVal2, pc, ?, csrVal);
        eInst <= _eInst;

        if (_eInst.iType == Unsupported) begin
            $fwrite(stderr, "Unsupported instruction at pc %x. Exiting.\n", pc);
            $finish;
        end

        // Memory access
        if (_eInst.iType == Ld) begin
            dmem.req(MemReq{op: Ld, addr: _eInst.addr, data: ?});
            end else if (_eInst.iType == St) begin
            let d <- dmem.req(MemReq{op: St, addr: _eInst.addr, data: _eInst.data});
        end

        stage <= WriteBack;

        // Update PC
        pc <= _eInst.brTaken ? wInst.addr : pc + 4;


    endrule

    rule doWriteBack(csrf.started && stage == WriteBack);
        let wInst = eInst;
        if (wInst.iType == Ld) begin
            wInst.data <- dmem.resp;
        end

        // Write back
        if (isValide(wInst.dst)) begin
            rf.wr(fromMaybe(?, wInst.dst), wInst.data);
        end

        csrf.wr(wInst.iType == Csrw ? wInst.csr : Invalid, wInst.data);

        stage <= Fetch;
    endrule
        

    method ActionValue#(Tuple2#(RIndx, Data)) cpuToHost;
        let ret <- cop.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !cop.started && memReady );
        cop.start;
        pc <= startpc;
    endmethod

    interface MemInit iMemInit = dummyMemInit;
    interface MemInit dMemInit = mem.init;
endmodule

