## Exercise 1 : Message FIFO

message types transferred by the message FIFO

``` verilog
typedef struct {
  CoreID            child;  // typedef Bit#(TLog#(CoreNum)) CoreID;
  Addr              addr;
  MSI               state;  // typedef enum { M, S, I } MSI deriving( Bits, Eq, FShow );
  Maybe#(CacheLine) data;
} CacheMemResp deriving(Eq, Bits, FShow);

typedef struct {
  CoreID      child;
  Addr        addr;
  MSI         state;
} CacheMemReq deriving(Eq, Bits, FShow);

typedef union tagged {
  CacheMemReq     Req;
  CacheMemResp    Resp;
} CacheMemMessage deriving(Eq, Bits, FShow);

interface MessageFifo#(numeric type n);
  method Action enq_resp(CacheMemResp d);
  method Action enq_req(CacheMemReq d);
  method Bool hasResp;
  method Bool hasReq;
  method Bool notEmpty;
  method CacheMemMessage first;
  method Action deq;
endinterface
```

## Exercise 2 : Message router

``` verilog
module mkMessageRouter(
  Vector#(CoreNum, MessageGet) c2r, Vector#(CoreNum, MessagePut) r2c, 
  MessageGet m2r, MessagePut r2m,
  Empty ifc 
);
```


``` verilog
interface MessageGet;
  method Bool hasResp;
  method Bool hasReq;
  method Bool notEmpty;
  method CacheMemMessage first;
  method Action deq;
endinterface
interface MessagePut;
  method Action enq_resp(CacheMemResp d);
  method Action enq_req(CacheMemReq d);
endinterface
```

```
    sending messages from the parent (m2r) to the correct L1 D cache (r2c), and
    sending messages from L1 D caches (c2r) to the parent (r2m).
```
>  response messages have priority over request messages just like the case in message FIFO.

## Exercise 3 : DCache


```
    id is the core ID, which will be attached to every message sent to the parent protocol processor.
    fromMem is the interface of the message FIFO from parent protocol processor (or more accurately the message router), so downgrade requests and upgrade responses can be read out from this interface.
    toMem is the interface of the message FIFO to parent protocol processor, so upgrade requests and downgrade responses should be sent to this interface.
    refDMem is for debugging, and currently you do not need to worry about it.
```

```
interface DCache;
  method Action req(MemReq r);
  method ActionValue#(MemResp) resp;
endinterface
```