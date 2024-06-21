import Vector::*;
import Complex::*;

import FftCommon::*;
import Fifo::*;

interface Fft;
    method Action enq(Vector#(FftPoints, ComplexData) in);
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
endinterface

(* synthesize *)
module mkFftCombinational(Fft);
    Fifo#(2,Vector#(FftPoints, ComplexData)) inFifo <- mkCFFifo;
    Fifo#(2,Vector#(FftPoints, ComplexData)) outFifo <- mkCFFifo;
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction
  
    rule doFft;
        if( inFifo.notEmpty && outFifo.notFull ) begin
            inFifo.deq;
            Vector#(4, Vector#(FftPoints, ComplexData)) stage_data;
            stage_data[0] = inFifo.first;
      
            for (StageIdx stage = 0; stage < 3; stage = stage + 1) begin
                stage_data[stage+1] = stage_f(stage, stage_data[stage]);
            end
            outFifo.enq(stage_data[3]);
        end
    endrule
    
    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod
  
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

(* synthesize *)
module mkFftFolded(Fft);
    Fifo#(2,Vector#(FftPoints, ComplexData)) inFifo <- mkCFFifo;
    Fifo#(2,Vector#(FftPoints, ComplexData)) outFifo <- mkCFFifo;
    Vector#(16, Bfly4) bfly <- replicateM(mkBfly4);
    Reg#(StageIdx) stagei <- mkReg(0);
    Reg#(Vector#(FftPoints, ComplexData)) sReg <- mkRegU;

    function Vector#(FftPoints, ComplexData) f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end
        stage_out = permute(stage_temp);
        return stage_out;
    endfunction

    rule doFft;
        //TODO: Implement the rest of this module
        Vector#(FftPoints, ComplexData) sxIn;
        // Input MUX of f
        if(stagei==0) 
            begin sxIn = inFifo.first; inFifo.deq(); end
        else 
            begin sxIn = sReg; end
        let sxOut = f(stagei, sxIn);    
        if(stagei==2) 
            begin outFifo.enq(sxOut); end
        else 
            begin sReg <= sxOut; end
        stagei <= (stagei==2) ? 0 : stagei+1;

    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in) if( inFifo.notFull );
        inFifo.enq(in);
    endmethod
  
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq if( outFifo.notEmpty );
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

(* synthesize *)
module mkFftInelasticPipeline(Fft);
    Fifo#(2,Vector#(FftPoints, ComplexData)) inFifo <- mkCFFifo;
    Fifo#(2,Vector#(FftPoints, ComplexData)) outFifo <- mkCFFifo;
    Vector#(3, Vector#(16, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));
    Vector#(2, Reg#(Vector#(FftPoints, ComplexData))) stageDataReg <- replicateM(mkRegU);
    Vector#(2, Reg#(Bool)) stageDataVld <- replicateM(mkReg(False));

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end
        stage_out = permute(stage_temp);
        return stage_out;
    endfunction    

    rule doFft;
        //TODO: Implement the rest of this module
        if(inFifo.notEmpty && outFifo.notFull) 
            begin stageDataReg[0] <= stage_f(0, inFifo.first); inFifo.deq(); stageDataVld[0] <= True; end 
        else 
            begin stageDataVld[0] <= False; end 
        if(stageDataVld[0]) 
            begin stageDataReg[1] <= stage_f(1, stageDataReg[0]); stageDataVld[1] <= True; end 
        else 
            begin stageDataVld[1] <= False; end 
        if(stageDataVld[1])
            begin outFifo.enq(stage_f(2, stageDataReg[1])); end
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod
  
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

(* synthesize *)
module mkFftElasticPipeline(Fft);
    Fifo#(2,Vector#(FftPoints, ComplexData)) inFifo <- mkCFFifo;
    Fifo#(2,Vector#(FftPoints, ComplexData)) outFifo <- mkCFFifo;
    Vector#(3, Vector#(16, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));
    Fifo#(2,Vector#(FftPoints, ComplexData)) stageFifo1 <- mkCFFifo;
    Fifo#(2,Vector#(FftPoints, ComplexData)) stageFifo2 <- mkCFFifo;

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end
        stage_out = permute(stage_temp);
        return stage_out;
    endfunction   

    //TODO: Implement the rest of this module
    // You should use more than one rule
    rule stage1;
        if(inFifo.notEmpty && stageFifo1.notFull) 
            begin stageFifo1.enq(stage_f(0, inFifo.first)); inFifo.deq(); end
    endrule

    rule stage2;
        if(stageFifo1.notEmpty && stageFifo2.notFull) 
            begin stageFifo2.enq(stage_f(1, stageFifo1.first)); stageFifo1.deq(); end
    endrule

    rule stage3;
        if(stageFifo2.notEmpty && outFifo.notFull)
            begin outFifo.enq(stage_f(2, stageFifo2.first)); stageFifo2.deq(); end
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod
  
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

interface SuperFoldedFft#(numeric type radix);
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
    method Action enq(Vector#(FftPoints, ComplexData) in);
endinterface

module mkFftSuperFolded(SuperFoldedFft#(radix)) provisos(Div#(TDiv#(FftPoints, 4), radix, times), Mul#(radix, times, TDiv#(FftPoints, 4)));
    Fifo#(2,Vector#(FftPoints, ComplexData)) inFifo <- mkCFFifo;
    Fifo#(2,Vector#(FftPoints, ComplexData)) outFifo <- mkCFFifo;
    Reg#(Bit#(6)) iter <- mkReg(0);
    Vector#(radix, Bfly4) bfly <- replicateM(mkBfly4);
    Reg#(Vector#(FftPoints, ComplexData)) stage_data <- mkRegU;
    Bit#(6) r = fromInteger(valueOf(radix));
    let foldNum = 16/r;

    function Vector#(FftPoints, ComplexData) f(Bit#(6) foldIdx, Vector#(FftPoints, ComplexData) stage_in);
        let stage = foldIdx / foldNum; // stage = 0,1,2
        let foldi = foldIdx % foldNum;  // foldi = 0, 1, 2, ..., foldNum
        Vector#(FftPoints, ComplexData) stage_temp = stage_in; 
        for (FftIdx i = 0; i < r ; i = i + 1)  begin
            FftIdx idx = (foldi*r+i) * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(truncate(stage), idx+j);
            end
            let y = bfly[i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end
        if(foldi == foldNum-1) return permute(stage_temp);
        else return stage_temp;
    endfunction

    rule doFft;
        //TODO: Implement the rest of this module
        Vector#(FftPoints, ComplexData) sxIn;
        if(iter == 0) begin sxIn = inFifo.first; inFifo.deq(); end 
        else sxIn = stage_data;
        let sxOut = f(iter, sxIn);
        if(iter == 3*foldNum-1) begin outFifo.enq(sxOut); iter <= 0; end
        else begin stage_data <= sxOut; iter <= iter + 1; end
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod
  
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

function Fft getFft(SuperFoldedFft#(radix) f);
    return (interface Fft;
        method enq = f.enq;
        method deq = f.deq;
    endinterface);
endfunction

(* synthesize *)
module mkFftSuperFolded4(Fft);
    SuperFoldedFft#(4) sfFft <- mkFftSuperFolded;
    return (getFft(sfFft));
endmodule
