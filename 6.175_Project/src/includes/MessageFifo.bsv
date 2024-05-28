import CacheTypes ::*;
import Fifo::*;

module mkMessageFifo(MessageFifo#(n));

    Fifo#(2, CacheMemResp) respFifo <- mkCFFifo;
    Fifo#(2, CacheMemReq ) reqFifo  <- mkCFFifo;

    method Action enq_resp(CacheMemResp d);
        respFifo.enq(d);
    endmethod

    method Action enq_req(CacheMemReq d);
        reqFifo.enq(d);
    endmethod

    method Bool hasResp = respFifo.notEmpty;
    method Bool hasReq  = reqFifo.notEmpty;
    // method Bool notEmpty = hasResp || hasReq;
    method Bool notEmpty = respFifo.notEmpty || reqFifo.notEmpty;   

    method CacheMemMessage first;
        if (respFifo.notEmpty) begin
            return tagged Resp respFifo.first;
        end else begin
            return tagged Req reqFifo.first;
        end 
    endmethod

    method Action deq;
        if (respFifo.notEmpty) begin
            respFifo.deq;
        end else begin
            reqFifo.deq;
        end
    endmethod


endmodule