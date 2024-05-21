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
function Bit#(TAdd#(n,n)) multiply_by_adding( Bit#(n) a, Bit#(n) b );
    // TODO: Implement this function in Exercise 2
    // First solution
    // Bit#(TAdd#(n,n)) ans = 0; 
    // for(Integer i = 0; i < valueOf(n); i = i + 1) begin
    //     if(a[i] == 1) begin
    //         ans = ans + (zeroExtend(b) << i);
    //     end
    // end 
    // return ans;
    // Another solution according to the 6.175 ppt
    Bit#(n) tp = 0; Bit#(n) prod = 0;
    for(Integer i = 0; i < valueOf(n); i = i + 1) begin
        Bit#(n) m = (a[i] == 0) ? 0 : b;
        Bit#(TAdd#(n,1)) sum = zeroExtend(tp) + zeroExtend(m);
        prod[i] = sum[0];
        tp = sum[valueOf(n):1];
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

    rule mulStep( i < fromInteger(valueOf(n)) );
        // TODO: Implement this in Exercise 4
        Bit#(n) m = (a[i] == 0) ? 0 : b;
        Bit#(TAdd#(n,1)) sum = zeroExtend(tp) + zeroExtend(m);
        prod[i] <= sum[0];
        tp <= sum[valueOf(n):1];
        i <= i + 1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 4
        Bool ready = (i == fromInteger(valueOf(n)+1)) ? True : False;
        return ready;
    endmethod

    method Action start( Bit#(n) aIn, Bit#(n) bIn );
        // TODO: Implement this in Exercise 4
        if( i == fromInteger(valueOf(n)+1)) begin  // Only having conducted .result method can let i == n + 1
            a <= aIn; b <= bIn;
            prod <= 0; tp <= 0; i <= 0;
        end
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 4
        Bool ready = (i == fromInteger(valueOf(n))) ? True : False;
        return ready;
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 4
        if(i == fromInteger(valueOf(n))) begin
            i <= i + 1;
            return {tp, prod};
        end else begin
            return 0;
        end
    endmethod
endmodule



// Booth Multiplier
module mkBoothMultiplier( Multiplier#(n) );
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    // rule mul_step( /* guard goes here */ );
    //     // TODO: Implement this in Exercise 6
    // endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 6
        return False;
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 6
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 6
        return False;
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 6
        return 0;
    endmethod
endmodule



// Radix-4 Booth Multiplier
module mkBoothMultiplierRadix4( Multiplier#(n) );
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)/2+1) );

    // rule mul_step( /* guard goes here */ );
    //     // TODO: Implement this in Exercise 8
    // endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 8
        return False;
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 8
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 8
        return False;
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 8
        return 0;
    endmethod
endmodule

