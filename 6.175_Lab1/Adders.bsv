import Multiplexer::*;

// Full adder functions

function Bit#(1) fa_sum( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
    return xor1( xor1( a, b ), c_in );
endfunction

function Bit#(1) fa_carry( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
    return or1( and1( a, b ), and1( xor1( a, b ), c_in ) );
endfunction

// 4 Bit full adder
// Exercise 4 (2 Points): Complete the code for add4 by using a for loop to properly connect all the uses of fa_sum and fa_carry.
function Bit#(5) add4( Bit#(4) a, Bit#(4) b, Bit#(1) c_in );
    Bit#(4) sum;
    Bit#(5) cout = 0;
    cout[0] = c_in;
    for (Integer i = 0; i < 4; i = i + 1)
    begin
        sum[i] = fa_sum( a[i], b[i], cout[i] );
        cout[i+1] = fa_carry( a[i], b[i], cout[i] );
    end
    return {cout[4], sum};
endfunction

// Adder interface

interface Adder8;
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
endinterface

// Adder modules

// RC = Ripple Carry
module mkRCAdder( Adder8 );
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
        Bit#(5) lower_result = add4( a[3:0], b[3:0], c_in );
        Bit#(5) upper_result = add4( a[7:4], b[7:4], lower_result[4] );
        return { upper_result , lower_result[3:0] };
    endmethod
endmodule

// CS = Carry Select
// Exercise 5 (5 Points): Complete the code for the carry-select adder in the module mkCSAdder.
module mkCSAdder( Adder8 );
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
        Bit#(5) lower_result      = add4( a[3:0], b[3:0], c_in );
        Bit#(5) upper_result_low  = add4( a[7:4], b[7:4], 1'b0 );
        Bit#(5) upper_result_high = add4( a[7:4], b[7:4], 1'b1 );
        Bit#(5) upper_result      = multiplexer5( lower_result[4], upper_result_low, upper_result_high );
        return { upper_result , lower_result[3:0] };
    endmethod
endmodule

