
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import Complex::*;

import FixedPoint::*;
import Vector::*;

import ComplexMP::*;
import Cordic::*;


typedef Server#(
    Vector#(nbins, ComplexMP#(isize, fsize, psize)),
    Vector#(nbins, ComplexMP#(isize, fsize, psize))
) PitchAdjust#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);

interface SettablePitchAdjust#(
numeric type nbins, numeric type isize,
numeric type fsize, numeric type psize
);
    interface PitchAdjust#(nbins, isize, fsize, psize) adjust;
    interface Put#(FixedPoint#(isize, fsize)) setFactor;
endinterface

// s - the amount each window is shifted from the previous window.
//
// factor - the amount to adjust the pitch.
//  1.0 makes no change. 2.0 goes up an octave, 0.5 goes down an octave, etc...
module mkPitchAdjust(Integer s, SettablePitchAdjust#(nbins, isize, fsize, psize) ifc) 
    provisos(Min#(isize, 1, 1), Add#(psize, a__, isize), Add#(psize, b__, TAdd#(isize, isize))) ;
    
    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) inputFIFO <- mkFIFO();
    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) outputFIFO <- mkFIFO();

    Vector#(nbins, Reg#(Phase#(psize))) inphases <- replicateM(mkReg(0));
    Reg#(Vector#(nbins, Phase#(psize))) outphases <- mkReg(replicate(0));

    Reg#(Maybe#(FixedPoint#(isize, fsize))) factor <- mkReg(tagged Invalid); 
    
    // pitch adjust implementation, can run in parallel
    rule adjust_impl if(isValid(factor));
        let indata = inputFIFO.first();
        inputFIFO.deq();
        Vector#(nbins,ComplexMP#(isize, fsize, psize)) outdata = replicate(cmplxmp(0.0, 0));
        Vector#(nbins, Phase#(psize)) outPhases = outphases;
        for(Integer i = 0; i < valueOf(nbins); i = i + 1) begin
            FixedPoint#(isize, fsize) i_fx = fromInteger(i);
            FixedPoint#(isize, fsize) i1_fx = fromInteger(i+1);
            let bin_fx = fxptMult(i_fx, fromMaybe(?, factor));
            let bin_fx_1 = fxptMult(i1_fx,fromMaybe(?, factor));
            Int#(isize) bin_idx = truncate(fxptGetInt(bin_fx));
            Int#(isize) bin_idx_1 = truncate(fxptGetInt(bin_fx_1));

            inphases[i] <= indata[i].phase;
            if(bin_idx_1!=bin_idx && bin_idx >= 0 && bin_idx < fromInteger(valueOf(nbins))) begin 
                let dphase = indata[i].phase - inphases[i];
                FixedPoint#(isize, fsize) dphase_fx = fromInt(dphase);
                let shifted_fx = fxptMult(fromMaybe(?, factor), dphase_fx);
                Phase#(psize) shifted = truncate(fxptGetInt(shifted_fx));
                outPhases[bin_idx] = outPhases[bin_idx] + shifted;
                outdata[bin_idx] = cmplxmp(indata[i].magnitude, outPhases[bin_idx]);
                // $display("idx:%d, inPhase:%d, dPhase:%d, shifted:%d, outPhase:%d", 
                //             bin_idx, indata[i].phase, dphase, shifted, outPhases[bin_idx] );
            end 
        end
        outphases <= outPhases;  
        outputFIFO.enq(outdata);
    endrule

    interface PitchAdjust adjust;
        interface Put request = toPut(inputFIFO);
        interface Get response = toGet(outputFIFO);
    endinterface

    interface Put setFactor;
        method Action put(FixedPoint#(isize, fsize) x);
            factor <= tagged Valid x;
        endmethod
    endinterface
endmodule

typedef Server#(
    Vector#(nbins, Complex#(FixedPoint#(isize, fsize))),
    Vector#(nbins, ComplexMP#(isize, fsize, psize))
)ToMP#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);

typedef Server#(
    Vector#(nbins, ComplexMP#(isize, fsize, psize)),
    Vector#(nbins, Complex#(FixedPoint#(isize, fsize)))
)FromMP#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);

module mkToMP(ToMP#(nbins, isize, fsize, psize)) provisos(Min#(isize, 1, 1), Min#(TAdd#(isize, fsize), 2, 2));

    Vector#(nbins, ToMagnitudePhase#(isize, fsize, psize)) tomps <- replicateM(mkCordicToMagnitudePhase());

    interface Put request;
        method Action put(Vector#(nbins, Complex#(FixedPoint#(isize, fsize))) indata);
            for(Integer i = 0; i < valueOf(nbins); i = i + 1) begin
                tomps[i].request.put(indata[i]);
            end
        endmethod
    endinterface

    interface Get response;
        method ActionValue#(Vector#(nbins, ComplexMP#(isize, fsize, psize)))  get();
            Vector#(nbins, ComplexMP#(isize, fsize, psize)) ans = newVector();
            for(Integer i = 0; i < valueOf(nbins); i = i + 1) begin
                let mpans <- tomps[i].response.get();
                ans[i] = mpans;
            end
            return ans;
        endmethod
    endinterface

endmodule

module mkFromMP(FromMP#(nbins, isize, fsize, psize)) provisos(Min#(isize, 1, 1), Min#(TAdd#(isize, fsize), 2, 2));

    Vector#(nbins, FromMagnitudePhase#(isize, fsize, psize)) frommps <- replicateM(mkCordicFromMagnitudePhase());

    interface Put request;
        method Action put(Vector#(nbins, ComplexMP#(isize, fsize, psize)) indata);
            for(Integer i = 0; i < valueOf(nbins); i = i + 1) begin
                frommps[i].request.put(indata[i]);
            end
        endmethod
    endinterface

    interface Get response;
        method ActionValue#(Vector#(nbins, Complex#(FixedPoint#(isize, fsize))))  get();
            Vector#(nbins, Complex#(FixedPoint#(isize, fsize))) ans = newVector();
            for(Integer i = 0; i < valueOf(nbins); i = i + 1) begin
                let mpans <- frommps[i].response.get();
                ans[i] = mpans;
            end
            return ans;
        endmethod
    endinterface

endmodule