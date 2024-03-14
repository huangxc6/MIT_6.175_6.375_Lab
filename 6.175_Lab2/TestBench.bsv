import TestBenchTemplates::*;
import Multipliers::*;

// Example testbenches
(* synthesize *)
module mkTbDumb();
    // function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
    // Empty tb <- mkTbMulFunction(multiply_unsigned, multiply_unsigned, True);
    function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
    function Bit#(16) ref_function( Bit#(8) a, Bit#(8) b )  = multiply_unsigned( a, b );
    Empty tb <- mkTbMulFunction(test_function, ref_function, True);
    return tb;
endmodule

(* synthesize *)
module mkTbFoldedMultiplier();
    Multiplier#(8) dut <- mkFoldedMultiplier();
    Empty tb <- mkTbMulModule(dut, multiply_signed, True);
    return tb;
endmodule

(* synthesize *)
module mkTbSignedVsUnsigned();
    // TODO: Implement test bench for Exercise 1
    // Exercise 1 (2 Points): tests if multiply_signed produces the same output as multiply_unsigned.
    function Bit#(16) signed_function( Bit#(8) a, Bit#(8) b ) = multiply_signed( a, b );
    Empty tb <- mkTbMulFunction(signed_function, multiply_unsigned, True);
    return tb;
endmodule

(* synthesize *)
module mkTbEx3();
    // TODO: Implement test bench for Exercise 3
    function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_by_adding( a, b );
    // Empty tb <- mkTbMulFunction(test_function, multiply_signed, True);    
    Empty tb <- mkTbMulFunction(test_function, multiply_unsigned, True);    
    return tb;
endmodule

(* synthesize *)
module mkTbEx5();
    // TODO: Implement test bench for Exercise 5
endmodule

(* synthesize *)
module mkTbEx7a();
    // TODO: Implement test bench for Exercise 7
endmodule

(* synthesize *)
module mkTbEx7b();
    // TODO: Implement test bench for Exercise 7
endmodule

(* synthesize *)
module mkTbEx9a();
    // TODO: Implement test bench for Exercise 9
endmodule

(* synthesize *)
module mkTbEx9b();
    // TODO: Implement test bench for Exercise 9
endmodule

