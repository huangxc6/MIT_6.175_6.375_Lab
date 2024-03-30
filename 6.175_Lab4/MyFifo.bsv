import Ehr::*;
import Vector::*;

//////////////////
// Fifo interface 

interface Fifo#(numeric type n, type t);
    method Bool notFull;
    method Action enq(t x);
    method Bool notEmpty;
    method Action deq;
    method t first;
    method Action clear;
endinterface

/////////////////
// Conflict FIFO

module mkMyConflictFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module
    method Bool notFull();
        return !full;
    endmethod

    method Action enq(t x) if (!full);
        data[enqP] <= x;
        let next_enqP = enqP + 1;
        if (next_enqP > max_index) begin
            next_enqP = 0;
        end
        if (next_enqP == deqP) begin
            full <= True;
        end
        enqP <= next_enqP;
        empty <= False;
    endmethod

    method Bool notEmpty();
        return !empty;
    endmethod

    method Action deq() if (!empty);
        let next_deqP = deqP + 1;
        if (next_deqP > max_index) begin
            next_deqP = 0;
        end
        if (next_deqP == enqP) begin
            empty <= True;
        end
        deqP <= next_deqP;
        full <= False;
    endmethod

    method t first() if (!empty);
        return data[deqP];
    endmethod

    method Action clear();
        enqP <= 0;
        deqP <= 0;
        empty <= True;
        full <= False;
    endmethod

endmodule

/////////////////
// Pipeline FIFO

// Intended schedule:
//      {notEmpty, first, deq} < {notFull, enq} < clear
// module mkMyPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
//     // n is size of fifo
//     // t is data type of fifo
// endmodule

/////////////////////////////
// Bypass FIFO without clear

// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
// module mkMyBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
//     // n is size of fifo
//     // t is data type of fifo
// endmodule

//////////////////////
// Conflict free fifo

// Intended schedule:
//      {notFull, enq} CF {notEmpty, first, deq}
//      {notFull, enq, notEmpty, first, deq} < clear
// module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
//     // n is size of fifo
//     // t is data type of fifo
// endmodule

