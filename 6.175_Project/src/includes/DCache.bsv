import CacheTypes::*;
import Vector::*;
import FShow::*;
import MemTypes::*;
import Types::*;
import ProcTypes::*;
import Fifo::*;
import Ehr::*;
import RefTypes::*;

typedef enum {
    Ready,
    StartMiss,
    SendFillReq,
    WaitFillResp,
    Resp
} CacheStatus deriving (Bits, Eq);

function Bool isStateM (MSI s) = (s == M);
function Bool isStateS (MSI s) = (s == S);
function Bool isStateI (MSI s) = (s == I);

module mkDCache#(CoreID id)(
    MessageGet fromMem,
    MessagePut toMem,
    RefDMem refDMem,
    DCache ifc
);

    // cache data array
    Vector#(CacheRows, Reg#(CacheLine)) dataArray <- replicateM(mkRegU);
    // tag array
    Vector#(CacheRows, Reg#(CacheTag)) tagArray <- replicateM(mkRegU);
    // MSI state array
    Vector#(CacheRows, Reg#(MSI)) stateArray <- replicateM(mkReg(I));

    Reg#(CacheStatus) mshr <- mkReg(Ready);

    Fifo#(8, Data) hitQ <- mkBypassFifo;
    Fifo#(8, MemReq) reqQ <- mkBypassFifo;
    Reg#(MemReq) buffer <- mkRegU ;
    Reg#(Maybe#(CacheLineAddr)) lineAddr <- mkReg(Invalid);

    rule doReady(mshr == Ready);
        MemReq r = reqQ.first;
        reqQ.deq;
        let wOffset = getWordSelect(r.addr);
        let idx = getIndex(r.addr);
        let tag = getTag(r.addr);
        let hit = (tagArray[idx] == tag && stateArray[idx] > I);
        let proceed = (r.op != Sc || (r.op == Sc && isValid(lineAddr) && fromMaybe(?, lineAddr) == getLineAddr(r.addr)));

        if (!proceed) begin
            hitQ.enq(scFail);
            refDMem.commit(r, Invalid, Valid(scFail));
            lineAddr <= Invalid;
        end else begin
            if (!hit) begin
                mshr <= StartMiss;
                buffer <= r;
            end else begin
                if (r.op == Ld || r.op == Lr) begin
                    hitQ.enq(dataArray[idx][wOffset]);
                    refDMem.commit(r, Valid(dataArray[idx]), Valid(dataArray[idx][wOffset]));  
                    if (r.op == Lr) begin
                        lineAddr <= tagged Valid (getLineAddr(r.addr));
                    end
                end else begin
                    if (isStateM(stateArray[idx])) begin
                        dataArray[idx][wOffset] <= r.data;
                        if (r.op == Sc) begin
                            hitQ.enq(scSucc);
                            refDMem.commit(r, Valid(dataArray[idx]), Valid(scSucc));
                            lineAddr <= Invalid;
                        end else begin
                            refDMem.commit(r, Valid(dataArray[idx]), Invalid);
                        end
                end else begin
                    mshr <= SendFillReq;
                    buffer <= r;
                end
            end
        end
        end
    
    endrule

    rule doStartMiss (mshr == StartMiss);
        let idx = getIndex(buffer.addr);
        let tag = tagArray[idx];
        let wOffset = getWordSelect(buffer.addr);

        if (!isStateI(stateArray[idx])) begin
            stateArray[idx] <= I;
            Maybe#(CacheLine) line = isStateM(stateArray[idx]) ? Valid(dataArray[idx]) : Invalid;
            let addr = {tag, idx, wOffset, 2'b0};
            toMem.enq_resp(CacheMemResp{
                child : id,
                addr : addr,
                state : I,
                data : line
            });
        end

        if (isValid(lineAddr) && fromMaybe(?, lineAddr) == getLineAddr(buffer.addr)) begin
            lineAddr <= Invalid;
        end

        mshr <= SendFillReq;
    endrule

    rule doSendFillReq(mshr == SendFillReq);
        let state = (buffer.op == Ld || buffer.op == Lr) ? S : M;
        toMem.enq_req(CacheMemReq{
            child : id,
            addr : buffer.addr,
            state : state
        });

        mshr <= WaitFillResp;
    endrule

    rule doWaitFillResp(mshr == WaitFillResp && fromMem.hasResp);
        let tag = getTag(buffer.addr);
        let idx = getIndex(buffer.addr);
        let wOffset = getWordSelect(buffer.addr);

        CacheMemResp x = ?;

        if (fromMem.first matches tagged Resp .r)begin
            x = r;
        end
        fromMem.deq;
        CacheLine line = isValid(x.data) ? fromMaybe(?, x.data) : dataArray[idx];

        if (buffer.op == St) begin 
            let old_line = isValid(x.data) ? fromMaybe(?, x.data) : dataArray[idx];
            refDMem.commit(buffer, Valid(old_line), Invalid);
            line[wOffset] = buffer.data;
        end else if (buffer.op == Sc) begin
            if (isValid(lineAddr) && fromMaybe(?, lineAddr) == getLineAddr(buffer.addr)) begin
                let lastMod = isValid(x.data) ? fromMaybe(?, x.data) : dataArray[idx];
                refDMem.commit(buffer, Valid(lastMod), Valid(scSucc));
                line[wOffset] = buffer.data;
                hitQ.enq(scSucc);
        end else begin
            hitQ.enq(scFail);
            refDMem.commit(buffer, Invalid, Valid(scFail));
        end
            lineAddr <= Invalid;
        end
    
        dataArray[idx] <= line;
        tagArray[idx] <= tag;
        stateArray[idx] <= x.state;
        mshr <= Resp;

    endrule

    rule doResp(mshr == Resp);
        let idx = getIndex(buffer.addr);
        let wOffset = getWordSelect(buffer.addr);
        if (buffer.op == Ld || buffer.op == Lr) begin
            hitQ.enq(dataArray[idx][wOffset]);
            refDMem.commit(buffer, Valid(dataArray[idx]), Valid(dataArray[idx][wOffset]));
            if (buffer.op == Lr) begin
                lineAddr <= tagged Valid (getLineAddr(buffer.addr));
            end
        end
        mshr <= Ready;
    endrule

    rule doDng(mshr != Resp && !fromMem.hasResp && fromMem.hasReq);
        CacheMemReq x = ?;
        if (fromMem.first matches tagged Req .r) begin
            x = r;
        end 
        let idx = getIndex(x.addr);
        let tag = getTag(x.addr);
        let wOffset = getWordSelect(x.addr);
        if (stateArray[idx] > x.state) begin
            Maybe#(CacheLine) line = isStateM(stateArray[idx]) ? Valid(dataArray[idx]) : Invalid;

            let addr = {tag, idx, wOffset, 2'b0};
            toMem.enq_resp(CacheMemResp{
                child : id,
                addr : addr,
                state : x.state,
                data : line
            });
            stateArray[idx] <= x.state;
            if (x.state == I) begin
                lineAddr <= Invalid;
            end
        end
        fromMem.deq;
    endrule

    method Action req(MemReq r);
        reqQ.enq(r);
        refDMem.issue(r);
    endmethod

    method ActionValue#(Data) resp;
        Data d = hitQ.first;
        hitQ.deq;
        return d;   
    endmethod


endmodule 