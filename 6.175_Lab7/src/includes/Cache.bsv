import CacheTypes::*;
import MemUtil::*;
import Fifo::*;
import Vector::*;
import Types::*;
import CMemTypes::*;

module mkTranslator(WideMem wideMem, Cache ifc);
    Fifo#(2, MemReq) reqFifo <- mkCFFifo;

    method Action req(MemReq r);
        if (r.op == Ld) reqFifo.enq(r);
        wideMem.req(toWideMemReq(r));
    endmethod

    method ActionValue#(MemResp) resp;
        let req = reqFifo.first;
        reqFifo.deq;

        let cacheLine <- wideMem.resp;
        CacheWordSelect offset = truncate(req.addr >> 2);
        $display("Translator: offset %d", offset);
        return cacheLine[offset];
    endmethod
endmodule

typedef enum {
    Ready,
    StartMiss,
    SendFillReq,
    WaitFillResp
} ReqStatus deriving (Bits, Eq);

// direct-mapped cache, write-miss allocate, write-back
module mkCache(WideMem wideMem, Cache ifc);
    // cache data array
    Vector#(CacheRows, Reg#(CacheLine)) dataArray <- replicateM(mkRegU);

    // tag array
    Vector#(CacheRows, Reg#(Maybe#(CacheTag))) tagArray <- replicateM(mkReg(tagged Invalid));

    // dirty array
    Vector#(CacheRows, Reg#(Bool)) dirtyArray <- replicateM(mkReg(False));

    Fifo#(1, Data) hitQ <- mkPipelineFifo;
    Reg#(MemReq) missReq <- mkRegU;
    Reg#(ReqStatus) mshr <- mkReg(Ready);

    // Index log2(16* 32/8 ) = 6
    function CacheIndex getIndex(Addr addr) = truncate(addr >> 6);
    // Offset log2(4) = 2
    function CacheWordSelect getOffset(Addr addr) = truncate(addr >> 2);
    // Tag
    function CacheTag getTag(Addr addr) = truncateLSB(addr);

    rule startMiss(mshr == StartMiss);
        let idx = getIndex(missReq.addr);
        let tag = tagArray[idx];
        let dirty = dirtyArray[idx];

        // if the cache line is dirty, write it back to memory
        if(isValid(tag) && dirty) begin
            let addr = {fromMaybe(?, tag), idx, 6'b0};
            let data = dataArray[idx];
            wideMem.req(WideMemReq {write_en: '1, addr: addr, data: data});
        end

        mshr <= SendFillReq;
    endrule 

    rule sendFillReq(mshr == SendFillReq);
        // send fill request to memory
        WideMemReq wideMemReq = toWideMemReq(missReq);
        wideMemReq.write_en = '0;
        wideMem.req(wideMemReq);

        mshr <= WaitFillResp;
    endrule

    rule waitFillResp(mshr == WaitFillResp);
        let idx = getIndex(missReq.addr);
        let tag = getTag(missReq.addr);
        let wOffset = getOffset(missReq.addr);
        let data <- wideMem.resp;
        tagArray[idx] <= tagged Valid tag;

        if(missReq.op == Ld) begin
            dirtyArray[idx] <= False;
            dataArray[idx] <= data;
            hitQ.enq(data[wOffset]);
        end else begin
            dirtyArray[idx] <= True;
            data[wOffset] = missReq.data;
            dataArray[idx] <= data;
        end

        mshr <= Ready;
    endrule 

    method Action req(MemReq r) if (mshr == Ready);
        let idx = getIndex(r.addr);
        let tag = getTag(r.addr);
        let wOffset = getOffset(r.addr);
        let currTag = tagArray[idx];
        let hit = isValid(currTag) ? (fromMaybe(?, currTag) == tag) : False;

        if (hit) begin
            let cacheLine = dataArray[idx];
            $display("Hit:idx = %x, tag = %x, wOffset = %x, data = %x", idx, tag, wOffset, cacheLine[wOffset]);
            if (r.op == Ld) hitQ.enq(cacheLine[wOffset]);
            else begin
                cacheLine[wOffset] = r.data;
                dataArray[idx] <= cacheLine;
                dirtyArray[idx] <= True;
            end
        end else begin
            missReq <= r;
            mshr <= StartMiss;
        end
    endmethod

    method ActionValue#(Data) resp;
        hitQ.deq;
        return hitQ.first;
    endmethod

endmodule


module mkCacheGroup(WideMem wideMem, Cache ifc);
    // cache data array
    Vector#(CacheGroups, Vector#(CacheGroupRows, Reg#(CacheLine))) dataArray <- replicateM(replicateM(mkRegU)); 

    // tag array
    Vector#(CacheGroups, Vector#(CacheGroupRows, Reg#(Maybe#(CacheGroupTag)))) tagArray <- replicateM(replicateM(mkReg(tagged Invalid)));

    // dirty array
    Vector#(CacheGroups, Vector#(CacheGroupRows, Reg#(Bool))) dirtyArray <- replicateM(replicateM(mkReg(False)));

    Fifo#(1, Data) hitQ <- mkPipelineFifo;
    Reg#(MemReq) missReq <- mkRegU;
    Reg#(CacheGroupIndex) emptyGroup <- mkRegU;
    Reg#(ReqStatus) mshr <- mkReg(Ready);

    // Index log2(16* 32/8 ) = 6
    function CacheGIndex getIndex(Addr addr) = truncate(addr >> 6);
    // Offset log2(4) = 2
    function CacheWordSelect getOffset(Addr addr) = truncate(addr >> 2);    
    // Tag
    function CacheGroupTag getTag(Addr addr) = truncateLSB(addr);

    rule startMiss(mshr == StartMiss);
        let idx = getIndex(missReq.addr);
        Maybe#(CacheGroupTag) dirtyTag = tagged Invalid;
        CacheGroupIndex dirtyGroup = ?;
        Bool dirtyHit = False;

        CacheGroupIndex tempGroup = fromInteger(0);

        for (Integer i = valueOf(CacheGroups) - 1; i >= 0; i = i - 1) begin
            let tag = tagArray[fromInteger(i)][idx];
            let dirty = dirtyArray[fromInteger(i)][idx];
            
            if (isValid(tag) && dirty) begin
                dirtyHit = True;
                dirtyTag = tag ;
                dirtyGroup = fromInteger(i);
            end

            if (!isValid(tag)) begin
                tempGroup = fromInteger(i);
            end
        end

        emptyGroup <= tempGroup;

        if (dirtyHit) begin
            let addr = {fromMaybe(?, dirtyTag), idx, 6'b0};
            let data = dataArray[dirtyGroup][idx];
            wideMem.req(WideMemReq {write_en: '1, addr: addr, data: data});
        end

        mshr <= SendFillReq;
    endrule

    rule sendFillReq(mshr == SendFillReq);
        // send fill request to memory
        WideMemReq wideMemReq = toWideMemReq(missReq);
        wideMemReq.write_en = '0;
        wideMem.req(wideMemReq);

        mshr <= WaitFillResp;
    endrule

    rule waitFillResp(mshr == WaitFillResp);
        let idx = getIndex(missReq.addr);
        let grp = emptyGroup;
        let tag = getTag(missReq.addr);
        let wOffset = getOffset(missReq.addr);
        let data <- wideMem.resp;
        tagArray[grp][idx] <= tagged Valid tag;

        if(missReq.op == Ld) begin
            dirtyArray[grp][idx] <= False;
            dataArray[grp][idx] <= data;
            hitQ.enq(data[wOffset]);
        end else begin
            dirtyArray[grp][idx] <= True;
            data[wOffset] = missReq.data;
            dataArray[grp][idx] <= data;
        end
        
        mshr <= Ready;
    endrule

    method Action req(MemReq r) if (mshr == Ready);
        let idx = getIndex(r.addr);
        let tag = getTag(r.addr);
        let woffset = getOffset(r.addr);
        
        Bool hit = False;
        CacheGroupIndex realGroup = ?;

        for (Integer i = 0; i < valueOf(CacheGroups); i = i + 1) begin
            let currTag = tagArray[fromInteger(i)][idx];
            let hitTemp = isValid(currTag) ? (fromMaybe(?, currTag) == tag) : False;

            if (hitTemp) begin
                hit = True;
                realGroup = fromInteger(i);
            end

            if (hit) begin
                let cacheLine = dataArray[realGroup][idx];
                if (r.op == Ld) hitQ.enq(cacheLine[woffset]);
                else begin
                    cacheLine[woffset] = r.data;
                    dataArray[realGroup][idx] <= cacheLine;
                    dirtyArray[realGroup][idx] <= True;
                end 
            end else begin
                missReq <= r;
                mshr <= StartMiss;
            end
        end
    endmethod

    method ActionValue#(Data) resp;
        hitQ.deq;
        return hitQ.first;
    endmethod

endmodule