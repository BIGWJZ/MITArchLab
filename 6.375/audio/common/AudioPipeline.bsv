
import Vector::*;
import ClientServer::*;
import GetPut::*;
import FixedPoint::*;
import AudioProcessorTypes::*;
import Chunker::*;
import FFT::*;
import FIRFilter::*;
import Splitter::*;
import FilterCoefficients::*;
import OverSampler::*;
import PitchAdjust::*;
import Overlayer::*;

module mkAudioPipeline(AudioProcessor);

    AudioProcessor fir <- mkFIRFilter(c);
    Chunker#(S, Sample) chunker <- mkChunker();
    OverSampler#(S, FFT_POINTS, Sample) oversampler <- mkOverSampler(replicate(0));

    FFT#(FFT_POINTS, FixedPoint#(16, 16)) fft <- mkFFT();
    ToMP#(FFT_POINTS, 16, 16, 16) tomp <- mkToMP();
    PitchAdjust#(FFT_POINTS, 16, 16, 16) pitchadjust <- mkPitchAdjust(valueOf(S), 2.0);
    FromMP#(FFT_POINTS, 16, 16, 16) frommp <- mkFromMP();
    FFT#(FFT_POINTS, FixedPoint#(16, 16)) ifft <- mkIFFT();

    Overlayer#(FFT_POINTS, S, Sample) overlayer <- mkOverlayer(replicate(0));
    Splitter#(S, Sample) splitter <- mkSplitter();

    rule fir_to_chunker (True);
        let x <- fir.getSampleOutput();
        chunker.request.put(x);
    endrule

    rule chunker_to_oversample (True);
        let x <- chunker.response.get();
        oversampler.request.put(x);
    endrule

    rule oversampler_to_fft (True);
        let x <- oversampler.response.get();
        fft.request.put(map(tocmplx, x));
    endrule

    rule fft_to_tomp (True);
        let x <- fft.response.get();
        tomp.request.put(x);
    endrule

    rule tomp_to_pitchadjust (True);
        let x <- tomp.response.get();
        pitchadjust.request.put(x);
    endrule

    rule pitchadjust_to_frommp (True);
        let x <- pitchadjust.response.get();
        frommp.request.put(x);
    endrule

    rule frommp_to_ifft (True);
        let x <- frommp.response.get();
        ifft.request.put(x);
    endrule

    rule ifft_to_overlayer (True);
        let x <- ifft.response.get();
        overlayer.request.put(map(frcmplx, x));
    endrule

    rule overlayer_to_splitter (True);
        let x <- overlayer.response.get();
        splitter.request.put(x);
    endrule
    
    method Action putSampleInput(Sample x);
        fir.putSampleInput(x);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        let x <- splitter.response.get();
        return x;
    endmethod

endmodule

