// onecycle processor with exception handling

import Types::*;
import ProcTypes::*;
import MemTypes::*;
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

(*synthesize*)
module mkProc(Proc);
    Reg #(Addr) pc   <- mkRegU   ;
    RFile       rf   <- mkRFile  ;
    IMemory     iMem <- mkIMemory;
    DMemory     dMem <- mkDMemory;
    CsrFile     csrf <- mkCsrFile;

    Bool memReady = iMem.init.done && dMem.init.done;
    rule test(!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    rule doProc(csrf.started);
        // Fetch instruction
        let inst   = iMem.req(pc);

        // Decode instruction
        let dInst  = decode(inst, csrf.getMstatus[2:1] == 2'b00);
        $display("[Decode] pc: %x, inst: %x, expanded: ", pc, inst, showInst(inst));

        // Reg read
        let rVal1  = rf.rd1(fromMaybe(?, dInst.src1));
        let rVal2  = rf.rd2(fromMaybe(?, dInst.src2));
        let csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        // Execute
        let eInst  = exec(dInst, rVal1, rVal2, pc, ?, csrVal); 

        // Memory access
        if(eInst.iType == Ld)begin
            eInst.data <- dMem.req(MemReq { op:Ld, addr:eInst.addr, data:? });
        end else if (eInst.iType == St)begin
            let d <- dMem.req(MemReq { op:St, addr:eInst.addr, data:eInst.data });
        end

        if(eInst.iType == NoPermission)begin
            $fwrite(stderr,"[Error] No permission to execute instruction at pc: %x.Exiting\n", pc);
            $finish;
        end else if (eInst.iType == Unsupported)begin
            $display("[Error] Unsupported instruction. Enter trap");
            let status = csrf.getMstatus << 3;
            status[2:0] = 3'b110;
            csrf.startExcep(pc, 32'h02, status);
            pc <= csrf.getMtvec;
        end else if (eInst.iType == ECall)begin
            $display("[Info] System call. Enter trap");
            let status = csrf.getMstatus << 3;
            status[2:0] = 3'b110;
            csrf.startExcep(pc, 32'h08, status);
            pc <= csrf.getMtvec;
        end else if (eInst.iType == ERet)begin
            $display("[Info] Return from trap");
            let status = csrf.getMstatus >> 3;
            status[11:9] = 3'b001;
            csrf.eret(status);
            pc <= csrf.getMepc;
        end else begin
            // Write back
            if (isValid(eInst.dst))begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end
            // Update pc
            pc <= eInst.brTaken ? eInst.addr : pc + 4;

            // Update csr if needed
            csrf.wr(eInst.iType == Csrrw ? eInst.csr : Invalid, eInst.data); 
        end
    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if (!csrf.started && memReady);
        csrf.start(0);
        $display("Start at pc %h\n", startpc);
        $fflush(stdout);
        pc <= startpc;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
        
endmodule