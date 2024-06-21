import Ehr::*;
import Vector::*;

//////////////////
// Fifo interface 

interface Fifo#(numeric type n, type t);
    method Bool notFull;
    method Action enq(t x);
    method Bool notEmpty;
    method Action deq;
    method t first;
    method Action clear;
endinterface

/////////////////
// Conflict FIFO

module mkMyConflictFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    function Bit#(TLog#(n)) ptrShiftRight(Bit#(TLog#(n)) curPtr);
        return (curPtr == max_index) ? 0 : curPtr + 1;
    endfunction
    
    // TODO: Implement all the methods for this module
    method Bool notFull();
        return !full;
    endmethod

    method Bool notEmpty();
        return !empty;
    endmethod

    method Action enq(t x) if(!full);
        data[enqP] <= x;
        enqP <= ptrShiftRight(enqP);
        empty <= False;
        if(ptrShiftRight(enqP) == deqP)
            full <= True;
    endmethod

    method Action deq() if(!empty);
        deqP <= ptrShiftRight(deqP);
        full <= False;
        if(ptrShiftRight(deqP) == enqP)
            empty <= True;
    endmethod

    method t first() if(!empty);
        return data[deqP];
    endmethod

    method Action clear();
        enqP <= 0; deqP <= 0;
        empty <= True; full <= False;
    endmethod
endmodule

/////////////////
// Pipeline FIFO

// Intended schedule:
//      {notEmpty, first, deq} < {notFull, enq} < clear
module mkMyPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Ehr#(3, Bit#(TLog#(n))) enqP     <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP     <- mkEhr(0);
    Ehr#(3, Bool)           empty    <- mkEhr(True);
    Ehr#(3, Bool)           full     <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    function Bit#(TLog#(n)) ptrShiftRight(Bit#(TLog#(n)) curPtr);
        return (curPtr == max_index) ? 0 : curPtr + 1;
    endfunction

    method Bool notFull();
        return !full[1];
    endmethod

    method Bool notEmpty();
        return !empty[0];
    endmethod

    method Action enq(t x) if(!full[1]);
        data[enqP[1]] <= x;
        enqP[1] <= ptrShiftRight(enqP[1]);
        empty[1] <= False;
        if(ptrShiftRight(enqP[1]) == deqP[1])
            full[1] <= True;
    endmethod

    method Action deq() if(!empty[0]);
        deqP[0] <= ptrShiftRight(deqP[0]);
        full[0] <= False;
        if(ptrShiftRight(deqP[0]) == enqP[0])
            empty[0] <= True;
    endmethod

    method t first() if(!empty[0]);
        return data[deqP[0]];
    endmethod

    method Action clear();
        enqP[2] <= 0; deqP[2] <= 0;
        empty[2] <= True; full[2] <= False;
    endmethod    
endmodule

/////////////////////////////
// Bypass FIFO without clear

// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Ehr#(3, Bit#(TLog#(n))) enqP     <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP     <- mkEhr(0);
    Ehr#(3, Bool)           empty    <- mkEhr(True);
    Ehr#(3, Bool)           full     <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    function Bit#(TLog#(n)) ptrShiftRight(Bit#(TLog#(n)) curPtr);
        return (curPtr == max_index) ? 0 : curPtr + 1;
    endfunction

    method Bool notFull();
        return !full[0];
    endmethod

    method Bool notEmpty();
        return !empty[1];
    endmethod

    method Action enq(t x) if(!full[0]);
        data[enqP[0]] <= x;
        enqP[0] <= ptrShiftRight(enqP[0]);
        empty[0] <= False;
        if(ptrShiftRight(enqP[0]) == deqP[0])
            full[0] <= True;
    endmethod

    method Action deq() if(!empty[1]);
        deqP[1] <= ptrShiftRight(deqP[1]);
        full[1] <= False;
        if(ptrShiftRight(deqP[1]) == enqP[1])
            empty[1] <= True;
    endmethod

    method t first() if(!empty[1]);
        return data[deqP[1]];
    endmethod

    method Action clear();
        enqP[2] <= 0; deqP[2] <= 0;
        empty[2] <= True; full[2] <= False;
    endmethod   
endmodule

//////////////////////
// Conflict free fifo

// Intended schedule:
//      {notFull, enq} CF {notEmpty, first, deq}
//      {notFull, enq, notEmpty, first, deq} < clear
module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Ehr#(2, Maybe#(t))      _enq     <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(Bool))   _deq     <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(Bool))   _clear   <- mkEhr(tagged Invalid);
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);

    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    function Bit#(TLog#(n)) ptrShiftRight(Bit#(TLog#(n)) curPtr);
        return (curPtr == max_index) ? 0 : curPtr + 1;
    endfunction

    (* no_implicit_conditions, fire_when_enabled *)
    rule canonicalize;
        let new_enqP = enqP;
        let new_deqP = deqP;
        if(isValid(_clear[1])) begin
            enqP <= 0; deqP <= 0;
            full <= False; empty <= False;
        end else begin
            if(isValid(_enq[1])) begin
                data[enqP] <= fromMaybe(?,_enq[1]);
                new_enqP = ptrShiftRight(enqP);
                enqP <= new_enqP;
            end
            if(isValid(_deq[1])) begin
                new_deqP = ptrShiftRight(deqP);
                deqP <= new_deqP;
            end
            case({pack(isValid(_enq[1])), pack(isValid(_deq[1])), pack((new_enqP==new_deqP))}) matches
                3'b??0: begin full <= False; empty <= False; end
                3'b101: begin full <= True;  empty <= False; end
                3'b011: begin full <= False; empty <= True;  end
                default:begin full <= full;  empty <= empty; end
            endcase
        end
        _enq[1] <= tagged Invalid;
        _deq[1] <= tagged Invalid;
        _clear[1] <= tagged Invalid;
    endrule

    method Bool notFull();
        return !full;
    endmethod

    method Bool notEmpty();
        return !empty;
    endmethod

    method Action enq(t x) if(!full);
        _enq[0] <= tagged Valid x;
    endmethod

    method Action deq() if(!empty);
        _deq[0] <= tagged Valid True;
    endmethod

    method t first() if(!empty);
        return data[deqP];
    endmethod

    method Action clear();
        _clear[0] <= tagged Valid True;
    endmethod  
endmodule

