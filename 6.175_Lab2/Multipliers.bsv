// Reference functions that use Bluespec's '*' operator
function Bit#(TAdd#(n,n)) multiply_unsigned( Bit#(n) a, Bit#(n) b );
    UInt#(n) a_uint = unpack(a);
    UInt#(n) b_uint = unpack(b);
    UInt#(TAdd#(n,n)) product_uint = zeroExtend(a_uint) * zeroExtend(b_uint);
    return pack( product_uint );
endfunction

function Bit#(TAdd#(n,n)) multiply_signed( Bit#(n) a, Bit#(n) b );
    Int#(n) a_int = unpack(a);
    Int#(n) b_int = unpack(b);
    Int#(TAdd#(n,n)) product_int = signExtend(a_int) * signExtend(b_int);
    return pack( product_int );
endfunction



// Multiplication by repeated addition
function Bit#(1) fa_sum( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
    return a ^ b ^ c_in;
endfunction

function Bit#(1) fa_carry( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
    return a & b | (a ^ b) & c_in;
endfunction

function Bit#(TAdd#(n,1)) addn( Bit#(n) a, Bit#(n) b, Bit#(1) c_in );
    Bit#(n) sum;
    Bit#(TAdd#(n,1)) cout = 0;
    cout[0] = c_in;
    for (Integer i = 0; i < valueOf(n); i = i + 1)
    begin
        sum[i] = fa_sum( a[i], b[i], cout[i] );
        cout[i+1] = fa_carry( a[i], b[i], cout[i] );
    end
    return {cout[valueOf(n)], sum};
endfunction

function Bit#(TAdd#(n,n)) multiply_by_adding( Bit#(n) a, Bit#(n) b );
    // TODO: Implement this function in Exercise 2
    Bit#(n) prod = 0;
    Bit#(n) tp   = 0;
    for (Integer i=0 ; i<valueOf(n) ; i=i+1)begin
        Bit#(n) m = (a[i]==0) ? 0 : b;
        Bit#(TAdd#(n,1)) sum = addn(tp, m, 0);
        prod[i] = sum[0];
        tp = sum[valueOf(n):1] ;
    end
    return {tp, prod};
endfunction


// Multiplier Interface
interface Multiplier#( numeric type n );
    method Bool start_ready();
    method Action start( Bit#(n) a, Bit#(n) b );
    method Bool result_ready();
    method ActionValue#(Bit#(TAdd#(n,n))) result();
endinterface



// Folded multiplier by repeated addition
module mkFoldedMultiplier( Multiplier#(n) );
    // You can use these registers or create your own if you want
    Reg#(Bit#(n)) a <- mkRegU();
    Reg#(Bit#(n)) b <- mkRegU();
    Reg#(Bit#(n)) prod <- mkRegU();
    Reg#(Bit#(n)) tp <- mkRegU();
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    rule mulStep( i < fromInteger(valueOf(n))/* guard goes here */ );
        // TODO: Implement this in Exercise 4
        Bit#(n) m = (a[i]==0) ? 0 : b;
        Bit#(TAdd#(n,1)) sum = addn(tp, m, 0);
        prod[i] <= sum[0];
        tp <= sum[valueOf(n):1] ;
        i <= i + 1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 4
        return i == fromInteger(valueOf(n) + 1);
    endmethod

    method Action start( Bit#(n) aIn, Bit#(n) bIn );
        // TODO: Implement this in Exercise 4
        if (i == fromInteger(valueOf(n) + 1))begin
            a <= aIn;
            b <= bIn;
            prod <= 0;
            tp <= 0;
            i <= 0;
        end
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 4
        return i == fromInteger(valueOf(n));
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 4
        if (i == fromInteger(valueOf(n)))begin
            i <= i + 1;
            return {tp, prod};
        end else
            return 0;
    endmethod
endmodule



// Booth Multiplier

function Bit#(n) sar(Bit#(n) a, Integer shift);
    Int#(n) a_int = unpack(a);
    Int#(n) result = a_int >> shift;
    return pack(result);
endfunction

module mkBoothMultiplier( Multiplier#(n) );
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    rule mul_step( i < fromInteger(valueOf(n))/* guard goes here */ );
        // TODO: Implement this in Exercise 6
        let pr = p[1:0];
        Bit#(TAdd#(TAdd#(n,n),1)) p_tmp = p; 
        if (pr == 2'b01) begin p_tmp = p + m_pos; end
        if (pr == 2'b10) begin p_tmp = p + m_neg; end
        p <= sar(p_tmp, 1);
        i <= i + 1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 6
        return i == fromInteger(valueOf(n) + 1);
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 6
        if (i == fromInteger(valueOf(n) + 1))begin
            m_neg <= {-m, 0};
            m_pos <= {m, 0} ;
            p <= {0,r,1'b0} ;
            i <= 0;
        end
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 6
        return i == fromInteger(valueOf(n));
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 6
        if (i == fromInteger(valueOf(n)))begin
            i <= i + 1;
            return p[2*valueOf(n):1];
        end else
            return 0;
    endmethod
endmodule



// Radix-4 Booth Multiplier

function Bit#(n) sal(Bit#(n) a, Integer shift);
    Int#(n) a_int = unpack(a);
    Int#(n) result = a_int << shift;
    return pack(result);
endfunction

module mkBoothMultiplierRadix4( Multiplier#(n) );
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)/2+1) );

    rule mul_step( i < fromInteger(valueOf(n)/2)/* guard goes here */ );
        // TODO: Implement this in Exercise 8
        let pr = p[2:0];
        Bit#(TAdd#(TAdd#(n,n),2)) p_tmp = p;
        if (pr == 3'b001) begin p_tmp = p + m_pos; end
        if (pr == 3'b010) begin p_tmp = p + m_pos; end
        if (pr == 3'b011) begin p_tmp = p + sal(m_pos, 1); end
        if (pr == 3'b100) begin p_tmp = p + sal(m_neg, 1); end
        if (pr == 3'b101) begin p_tmp = p + m_neg; end
        if (pr == 3'b110) begin p_tmp = p + m_neg; end
        p <= sar(p_tmp, 2);
        i <= i + 1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 8
        return i == fromInteger(valueOf(n)/2 + 1);
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 8
        if (i == fromInteger(valueOf(n)/2 + 1))begin
            m_neg <= {msb(-m), (-m), 0};
            m_pos <= {msb(m) ,   m , 0} ;
            p <= {0,r,1'b0} ;
            i <= 0;
        end
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 8
        return i == fromInteger(valueOf(n)/2);
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 8
        if (i == fromInteger(valueOf(n)/2))begin
            i <= i + 1;
            return p[2*valueOf(n):1];
        end else
            return 0;
    endmethod
endmodule

