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

    // TODO: Implement all the methods for this module
    
    method Bool notFull(); return !full; endmethod
    
    method Action enq(t x) if (!full);
        data[enqP] <= x;
        let _enqP = enqP + 1;
        if (_enqP > max_index) begin _enqP = 0; end
        if (_enqP == deqP) begin full <= True; end
        empty <= False;
        enqP <= _enqP;
    endmethod
    
    method Bool notEmpty(); return !empty; endmethod
    
    method Action deq() if (!empty);
        let _deqP = deqP + 1;
        if (_deqP > max_index) begin _deqP = 0; end
        if (enqP == _deqP) begin empty <= True; end
        full <= False;
        deqP <= _deqP;
    endmethod
    
    method t first() if (!empty); return data[deqP]; endmethod
    
    method Action clear();
        enqP <= 0;
        deqP <= 0;
        empty <= True;
        full <= False;
    endmethod
    
endmodule

/////////////////
// Pipeline FIFO

// Intended schedule:
//      {notEmpty, first, deq} < {notFull, enq} < clear
module mkMyPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    
    Vector#(n, Reg#(t))     data  <- replicateM(mkRegU());
    Ehr#(3, Bit#(TLog#(n))) enqP  <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP  <- mkEhr(0);
    Ehr#(3, Bool)           empty <- mkEhr(True);
    Ehr#(3, Bool)           full  <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module

    method Bool notFull(); return !full[1]; endmethod

    method Action enq(t x) if (!full[1]);
        data[enqP[1]] <= x;
        let _enqP = enqP[1] + 1;
        if (_enqP > max_index) begin _enqP = 0; end
        if (_enqP == deqP[1]) begin full[1] <= True; end
        empty[1] <= False;
        enqP[1] <= _enqP;
    endmethod

    method Bool notEmpty(); return !empty[0]; endmethod

    method Action deq() if (!empty[0]);
        let _deqP = deqP[0] + 1;
        if (_deqP > max_index) begin _deqP = 0; end
        if (enqP[0] == _deqP) begin empty[0] <= True; end
        full[0] <= False;
        deqP[0] <= _deqP;
    endmethod

    method t first() if (!empty[0]); return data[deqP[0]]; endmethod

    method Action clear();
        enqP[2] <= 0;
        deqP[2] <= 0;
        empty[2] <= True;
        full[2] <= False;
    endmethod
    
endmodule

/////////////////////////////
// Bypass FIFO without clear

// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo

    Vector#(n, Ehr#(3, t))     data  <- replicateM(mkEhrU());
    Ehr#(3, Bit#(TLog#(n))) enqP  <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP  <- mkEhr(0);
    Ehr#(3, Bool)           empty <- mkEhr(True);
    Ehr#(3, Bool)           full  <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module

    method Bool notFull(); return !full[0]; endmethod

    method Action enq(t x) if (!full[0]);
        data[enqP[0]][0] <= x;
        let _enqP = enqP[0] + 1;
        if (_enqP > max_index) begin _enqP = 0; end
        if (_enqP == deqP[0]) begin full[0] <= True; end
        empty[0] <= False;
        enqP[0] <= _enqP;
    endmethod

    method Bool notEmpty(); return !empty[1]; endmethod

    method Action deq() if (!empty[1]);
        let _deqP = deqP[1] + 1;
        if (_deqP > max_index) begin _deqP = 0; end
        if (enqP[1] == _deqP) begin empty[1] <= True; end
        full[1] <= False;
        deqP[1] <= _deqP;
    endmethod

    method t first() if (!empty[1]); return data[deqP[1]][1]; endmethod

    method Action clear();
        enqP[2] <= 0;
        deqP[2] <= 0;
        empty[2] <= True;
        full[2] <= False;
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
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);

    Ehr#(2, Maybe#(t)) enqEhr      <- mkEhr(tagged Invalid);
    Ehr#(2, Bool)      deqEhr      <- mkEhr(False);
    Ehr#(2, Bool)      clearEhr    <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module

    (* no_implicit_conditions *)
    (* fire_when_enabled *)
    rule canonicalize;
        if (clearEhr[1]) begin
            enqP <= 0;
            deqP <= 0;
            empty <= True;
            full <= False;
        end else begin
            let _enqP = enqP;
            let _deqP = deqP;
            if (isValid(enqEhr[1]) && !full) begin
                data[enqP] <= fromMaybe(?, enqEhr[1]);
                _enqP = enqP + 1;
                if (_enqP > max_index) begin _enqP = 0; end
            end
            if (deqEhr[1] && !empty) begin
                _deqP = deqP + 1;
                if (_deqP > max_index) begin _deqP = 0; end
            end
            if (isValid(enqEhr[1]) && !full) begin
                if (deqEhr[1] && !empty) begin full <= False; end
                else if (_enqP == _deqP) begin full <= True; end
                empty <= False;
            end else if (deqEhr[1] && !empty) begin
                if (_enqP == _deqP) begin empty <= True; end
                full <= False;
            end
            enqP <= _enqP;
            deqP <= _deqP;
        end
        enqEhr[1] <= tagged Invalid;
        deqEhr[1] <= False;
        clearEhr[1] <= False;
    endrule

    method Bool notFull(); return !full; endmethod

    method Action enq(t x) if (!full);
        enqEhr[0] <= tagged Valid x;
    endmethod

    method Bool notEmpty(); return !empty; endmethod

    method Action deq() if (!empty);
        deqEhr[0] <= True;
    endmethod

    method t first() if (!empty); return data[deqP]; endmethod

    method Action clear();
        clearEhr[0] <= True;
    endmethod
    
endmodule

