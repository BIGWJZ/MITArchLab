
import ClientServer::*;
import FIFO::*;
import GetPut::*;

import FixedPoint::*;
import Vector::*;

import ComplexMP::*;


typedef Server#(
    Vector#(nbins, ComplexMP#(isize, fsize, psize)),
    Vector#(nbins, ComplexMP#(isize, fsize, psize))
) PitchAdjust#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);


// s - the amount each window is shifted from the previous window.
//
// factor - the amount to adjust the pitch.
//  1.0 makes no change. 2.0 goes up an octave, 0.5 goes down an octave, etc...
module mkPitchAdjust(Integer s, FixedPoint#(isize, fsize) factor, PitchAdjust#(nbins, isize, fsize, psize) ifc) 
    provisos(Min#(isize, 1, 1), Add#(psize, a__, isize), Add#(psize, b__, TAdd#(isize, isize))) ;
    
    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) inputFIFO <- mkFIFO();
    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) outputFIFO <- mkFIFO();

    Vector#(nbins, Reg#(Phase#(psize))) inphases <- replicateM(mkReg(0));
    Vector#(nbins, Reg#(Phase#(psize))) outphases <- replicateM(mkReg(0));

    // Pre-calculate the new bin index
    Vector#(nbins, Maybe#(Int#(isize))) bins_idx = newVector();
    for(Integer i = 0; i < valueOf(nbins); i = i + 1) begin
        FixedPoint#(isize, fsize) i_fx = fromInteger(i);
        FixedPoint#(isize, fsize) i1_fx = fromInteger(i+1);
        let new_bin_fx = fxptMult(i_fx, factor);
        let new_bin_1_fx = fxptMult(i1_fx,factor);
        Int#(isize) new_bin = truncate(fxptGetInt(new_bin_fx));
        Int#(isize) new_bin_1 = truncate(fxptGetInt(new_bin_1_fx));
        if(new_bin_1!=new_bin && new_bin >= 0 && new_bin < fromInteger(valueOf(nbins))) begin 
            bins_idx[i] = tagged Valid new_bin; end
        else begin bins_idx[i] = tagged Invalid; end
    end
    
    rule adjust;
        // for(Integer i=0; i < valueOf(nbins); i = i + 1) begin $display("%d",fromMaybe(-1,bins_idx[i])); end
        let indata = inputFIFO.first();
        inputFIFO.deq();
        Vector#(nbins,ComplexMP#(isize, fsize, psize)) outdata = replicate(cmplxmp(0.0, 0));
        for(Integer i = 0; i < valueOf(nbins); i = i + 1) begin
            let dphase = indata[i].phase - inphases[i];
            inphases[i] <= indata[i].phase;
            FixedPoint#(isize, fsize) dphase_fx = fromInt(dphase);
            let shifted_fx = fxptMult(factor,dphase_fx);
            Phase#(psize) shifted = truncate(fxptGetInt(shifted_fx));
            if(isValid(bins_idx[i])) begin
                let bin_idx = fromMaybe(?, bins_idx[i]);
                outphases[bin_idx] <= outphases[bin_idx] + shifted;
                outdata[bin_idx] = cmplxmp(indata[i].magnitude, (outphases[bin_idx] + shifted));
                $display("idx:%d, inPhase:%d, dPhase:%d, shifted:%d, outPhase:%d", 
                            bin_idx, indata[i].phase, dphase, shifted, outdata[bin_idx].phase);
            end
        end
        outputFIFO.enq(outdata);
    endrule

    interface Put request = toPut(inputFIFO);
    interface Get response = toGet(outputFIFO);
endmodule

