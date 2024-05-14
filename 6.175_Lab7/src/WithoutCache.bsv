// WithoutCache.bsv
//
// This is a six stage pipelined implementation with branch history table(BHT) and return address stack (RAS) of the RISC-V processor.
// using DDR3 memory for instruction and data memory. Without cache.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import Btb::*;
import Scoreboard::*;
import Bht::*;
import Ras::*;

import Memory::*;
import SimMem::*;
import ClientServer::*;
import CacheTypes::*;
import WideMemInit::*;
import MemUtil::*;
import Cache::*;

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

//  a JAL or JALR instruction with rd=x1 is commonly used 
// as the jump to initiate a function call. 
function Bool isFuncCall(RIndx rd);
    let x1 = 5'b00001;
    return (rd == x1);
endfunction

//  a JALR instruction with rd=x0 and rs1=x1 is commonly used 
// as the return instruction from a function call.
function Bool isFuncReturn(RIndx rd, RIndx rs1);
    let x0 = 5'b00000;
    let x1 = 5'b00001;
    return (rd == x0 && rs1 == x1);
endfunction

typedef struct {
    Addr pc;
    Addr nextPc;
} ExeRedirect deriving (Bits, Eq);

// (* synthesize *)
module mkProc#(Fifo#(2, DDR3_Req) ddr3ReqFifo, Fifo#(2, DDR3_Resp) ddr3RespFifo)(Proc);
    Ehr#(4, Addr)   pcReg <- mkEhr(?);
    RFile           rf    <- mkRFile;
    Scoreboard#(6)  sb    <- mkCFScoreboard;
    // FPGAMemory      iMem  <- mkFPGAMemory;
    // FPGAMemory      dMem  <- mkFPGAMemory;
    CsrFile         csrf  <- mkCsrFile;
    Btb#(6)         btb   <- mkBtb;  // 6-bit branch predictor
    Bht#(8)         bht   <- mkBht;  // 8-bit branch history table
    Ras#(8)         ras   <- mkRas;  // 8-entry return address stack   

    Reg#(Bool)      eEpoch <- mkReg(False);
    Reg#(Bool)      rEpoch <- mkReg(False);
    Reg#(Bool)      dEpoch <- mkReg(False);
    Fifo#(6, Fetch2Decode)      f2dFifo  <- mkCFFifo; // 6 is the size of the FIFO
    Fifo#(6, Decode2RegRead)    d2rFifo <- mkCFFifo;
    Fifo#(6, RegRead2Exec)      r2eFifo <- mkCFFifo;
    Fifo#(6, Exec2Mem)          e2mFifo  <- mkCFFifo;
    Fifo#(6, Mem2WriteBack)     m2wFifo  <- mkCFFifo; 

    Bool memReady = True;
    // wrap DDR3 to WideMem interface
    WideMem wideMemWrapper <- mkWideMemFromDDR3(ddr3ReqFifo, ddr3RespFifo); 
    // split WideMem interface to two (use it in a multiplexed way) 
	// This spliter only take action after reset (i.e. memReady && csrf.started)
	// otherwise the guard may fail, and we get garbage DDR3 resp
    Vector#(2, WideMem) wideMems <- mkSplitWideMem(memReady && csrf.started, wideMemWrapper);
    // Instruction cache should use wideMems[1]
	// Data cache should use wideMems[0]
    Cache iMem <- mkTranslator(wideMems[1]);
    Cache dMem <- mkTranslator(wideMems[0]);

    // some garbage may get into ddr3RespFifo during soft reset
	// this rule drains all such garbage
	rule drainMemResponses( !csrf.started );
		ddr3RespFifo.deq;
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
            // for function call
            if ((dInst.iType == J || dInst.iType == Jr) && isFuncCall(fromMaybe(?, dInst.dst))) begin
                // push the return address to the RAS
                ras.push(d2r.pc + 4);
                $display("Function call at pc %x, pushed return address %x to RAS", d2r.pc, d2r.pc + 4);
            end
            if (dInst.iType == Jr && isFuncReturn(fromMaybe(?, dInst.dst), fromMaybe(?, dInst.src1))) begin
                // pop the return address from the RAS
                predPc <- ras.pop;
                $display("Function return at pc %x, popped return address %x from RAS", d2r.pc, predPc);
            end

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

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady && !ddr3RespFifo.notEmpty );
		csrf.start(0); // only 1 core, id = 0
		$display("Start at pc 200\n");
		$fflush(stdout);
        pcReg[0] <= startpc;
    endmethod
        
endmodule