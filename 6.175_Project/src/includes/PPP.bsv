import ProcTypes::*;
import Types::*;
import MemTypes::*;
import CacheTypes::*;
import MessageFifo::*;
import Vector::*;
import FShow::*;

function Bool isStateM (MSI s) = (s == M);
function Bool isStateS (MSI s) = (s == S);
function Bool isStateI (MSI s) = (s == I);

function Bool isCompatible(MSI s1, MSI s2) ;
    return (s1 == I) || (s2 == I) || (s1 == S && s2 == S);
endfunction

module mkPPP(
    MessageGet c2m,
    MessagePut m2c,
    WideMem mem,
    Empty ifc
);
    Vector#(CoreNum, Vector#(CacheRows, Reg#(MSI)))      childStateArray <- replicateM(replicateM(mkReg(I))); // CacheRows = 16
    Vector#(CoreNum, Vector#(CacheRows, Reg#(CacheTag))) childTagArray   <- replicateM(replicateM(mkRegU));
    Vector#(CoreNum, Vector#(CacheRows, Reg#(Bool)))     waitStateArray  <- replicateM(replicateM(mkReg(False)));

    Reg#(Bool)  missReg  <- mkReg(False);
    Reg#(Bool)  readyReg <- mkReg(False);

    rule parentResp(!c2m.hasResp && !missReg && readyReg); 
        let req = c2m.first.Req;
        let idx = getIndex(req.addr);
        let tag = getTag(req.addr);
        let child = req.child;
        Bool willConflict = False;
        for (Integer i = 0; i < valueOf(CoreNum); i = i + 1) begin
            if (fromInteger(i) != child) begin
                MSI s = (childTagArray[i][idx] == tag) ? childStateArray[i][idx] : I;
                if(!isCompatible(s, req.state) || waitStateArray[child][idx]) begin
                    willConflict = True;
                end
            end
        end

        if (!willConflict) begin
            MSI state = (childTagArray[child][idx] == tag) ? childStateArray[child][idx] : I;
            if (!isStateI(state)) begin
                m2c.enq_resp(CacheMemResp{
                    child: child,
                    addr: req.addr,
                    state: req.state,
                    data: Invalid
                });
                childStateArray[child][idx] <= req.state;
                childTagArray[child][idx] <= tag;
                c2m.deq;
            end else begin
                mem.req(WideMemReq{
                    write_en: '0,
                    addr: req.addr,
                    data: ?
                });
                missReg <= True;
            end
            readyReg <= False;
        end
        
    endrule

    rule dwn(!c2m.hasResp && !missReg && !readyReg);
        let req = c2m.first.Req;
        let idx = getIndex(req.addr);
        let tag = getTag(req.addr);
        let child = req.child;
        
        Maybe#(Integer) sendCore = tagged Invalid;
        for (Integer i = 0; i < valueOf(CoreNum); i = i + 1) begin
            if (fromInteger(i) != child) begin
                MSI state = (childTagArray[i][idx] == tag) ? childStateArray[i][idx] : I;
                if (!isCompatible(state, req.state) && !waitStateArray[i][idx]) begin
                    if (!isValid(sendCore)) begin
                        sendCore = tagged Valid i;
                    end
                end
            end
        end

        if (!isValid(sendCore)) begin
            readyReg <= True;
        end else begin
            waitStateArray[fromMaybe(?, sendCore)][idx] <= True;
            m2c.enq_req(CacheMemReq{
                child: fromInteger(fromMaybe(?, sendCore)),
                addr: req.addr,
                state: (req.state == M ? I : S)
            });
        end
        
    endrule

    rule parentDataResp(!c2m.hasResp && missReg);
        let req = c2m.first.Req;
        let idx = getIndex(req.addr);
        let tag = getTag(req.addr);
        let child = req.child;
        let line <- mem.resp();

        m2c.enq_resp(CacheMemResp{
            child: child,
            addr: req.addr,
            state: req.state,
            data: Valid(line)
        });

        childStateArray[child][idx] <= req.state;
        childTagArray[child][idx] <= tag;
        c2m.deq;
        missReg <= False;
        
    endrule

    rule dwnRsp(c2m.hasResp);
        let resp = c2m.first.Resp;
        c2m.deq;
        let idx = getIndex(resp.addr);
        let tag = getTag(resp.addr);
        let child = resp.child;

        MSI state = (childTagArray[child][idx] == tag) ? childStateArray[child][idx] : I;
        if (isStateM(state)) begin
            mem.req(WideMemReq{
                write_en: '1,
                addr: resp.addr,
                data: fromMaybe(?, resp.data)
            });
        end

        childStateArray[child][idx] <= resp.state;
        waitStateArray[child][idx] <= False;
        childTagArray[child][idx] <= tag;
        
    endrule
    
endmodule : mkPPP