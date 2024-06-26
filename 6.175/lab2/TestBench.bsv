import TestBenchTemplates::*;
import Multipliers::*;

// Example testbenches
(* synthesize *)
module mkTbDumb();
    function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
    Empty tb <- mkTbMulFunction(test_function, multiply_unsigned, True);
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
    function Bit#(16) test_8bit_unsigned_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b ); // Only need once explicit announcement
    Empty tb <- mkTbMulFunction(test_8bit_unsigned_function, multiply_signed, True);
    return tb;
endmodule

(* synthesize *)
module mkTbEx3();
    // TODO: Implement test bench for Exercise 3
    function Bit#(16) test_adding_function( Bit#(8) a, Bit#(8) b ) = multiply_by_adding( a, b );
    Empty tb <- mkTbMulFunction(test_adding_function, multiply_unsigned, False);
    return tb;
endmodule

(* synthesize *)
module mkTbEx5();
    // TODO: Implement test bench for Exercise 5
    Multiplier#(8) dut <- mkFoldedMultiplier();
    function Bit#(16) refer_function( Bit#(8) a, Bit#(8) b ) = multiply_by_adding( a, b );
    Empty tb <- mkTbMulModule(dut, refer_function, False);
endmodule

(* synthesize *)
module mkTbEx7a();
    // TODO: Implement test bench for Exercise 7
    Multiplier#(8) dut <- mkBoothMultiplier();
    Empty tb <- mkTbMulModule(dut, multiply_signed, True);
endmodule

(* synthesize *)
module mkTbEx7b();
    // TODO: Implement test bench for Exercise 7
    Multiplier#(64) dut <- mkBoothMultiplier();
    Empty tb <- mkTbMulModule(dut, multiply_signed, False);
endmodule

(* synthesize *)
module mkTbEx9a();
    // TODO: Implement test bench for Exercise 9
    Multiplier#(8) dut <- mkBoothMultiplierRadix4();
    Empty tb <- mkTbMulModule(dut, multiply_signed, True);
endmodule

(* synthesize *)
module mkTbEx9b();
    // TODO: Implement test bench for Exercise 9
    Multiplier#(64) dut <- mkBoothMultiplierRadix4();
    Empty tb <- mkTbMulModule(dut, multiply_signed, False);
endmodule

