// TwoCycle.bsv
//
// This is a two cycle implementation of the SMIPS processor.

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

typedef enum {Fetch, Execute} Stage deriving (Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    IMemory   imem <- mkIMemory;
    DMemory   dmem <- mkDMemory;
    CsrFile  csrf <- mkCsrFile;

    Bool memReady = imem.init.done() && dmem.init.done();

    // TODO: Complete the implementation of this processor

    rule test (!memReady);
        let e = tagged InitDone;
        imem.init.request.put(e);
        dmem.init.request.put(e);
    endrule

    Reg#(Stage) stage <- mkReg(Fetch);
    Reg#(DecodedInst) dInst <- mkRegU;

    rule doProc(csrf.started);
        if (stage == Fetch) begin
            let inst = imem.req(pc);

            // Decode the instruction
            dInst <= decode(inst);

            // trace - print the instruction
            $display("pc=%h inst=%h expanded=", pc, inst, showInst(inst));
            $fflush(stdout);

            stage <= Execute;
        end else begin
            // read registers
            Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
            Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));

            // read CSR values
            Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

            // Execute
            ExecInst eInst = exec(dInst, rVal1, rVal2, pc, ?, csrVal);
            // The fifth argument above is the predicted pc, to detect if it was mispredicted. 
	    	// Since there is no branch prediction, this field is sent with a random value

            // check unsupported instruction at commit time. Exiting
            if(eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
                $finish;
            end

            // memory
            if (eInst.iType == Ld) begin
                eInst.data <- dmem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
            end else if (eInst.iType == St) begin
                let d <- dmem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
            end

            // write back
            if (isValid(eInst.dst)) begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end

            // update pc
            pc <= eInst.brTaken ? eInst.addr : pc + 4;

            // CSR write for sending data to host & stats
            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
            stage <= Fetch;
        end
    endrule


    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
        $display("Start at pc 200\n");
	    $fflush(stdout);
        pc <= startpc;
    endmethod

    interface MemInit iMemInit = imem.init;
    interface MemInit dMemInit = dmem.init;
endmodule

