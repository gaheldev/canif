module waveforms;

import core.stdc.stdio;

import gui;

import core.atomic;
import dplug.core;
import dplug.gui;
import dplug.canvas;
import dplug.client;

import std.algorithm;

/// Displays input and clipped output waveforms
final class UIWaveforms : UIElement
{
public:
nothrow:
@nogc:

    enum SAMPLES_IN_FIFO = 1024;
    enum SAMPLES_TO_DISPLAY = 512;
    enum INPUT_SUBSAMPLING = 1;

    this(UIContext context)
    {
        super(context, flagRaw | flagAnimated);
        _inputFIFO.initialize(SAMPLES_IN_FIFO,INPUT_SUBSAMPLING);
        _outputFIFO.initialize(SAMPLES_IN_FIFO,INPUT_SUBSAMPLING);
        _inputTempState[] = 0.0f;
        _outputTempState[] = 0.0f;
        _stateToDisplay[] = 0.5f;
        _inputStateToDisplay = makeRingBufferNoGC!float(SAMPLES_TO_DISPLAY);
        _outputStateToDisplay = makeRingBufferNoGC!float(SAMPLES_TO_DISPLAY);
        for (int i=0; i<SAMPLES_TO_DISPLAY; i++)
        {
            _inputStateToDisplay.pushBack(0.0f);
            _outputStateToDisplay.pushBack(0.0f);
        }
    }

    ~this()
    {
    }

    override void onAnimate(double dt, double time)
    {
        bool needRedraw = false;
        int nbSamplesInput  = _inputFIFO.readOldestDataAndDropSome(_inputTempState[], dt);
        int nbSamplesOutput = _outputFIFO.readOldestDataAndDropSome(_outputTempState[], dt);

        for (int i=0; i<nbSamplesInput; i++)
            _inputStateToDisplay.pushBack(_inputTempState[i]);
        for (int i=0; i<nbSamplesOutput; i++)
            _outputStateToDisplay.pushBack(_outputTempState[i]);

        if (nbSamplesInput)
        {
            needRedraw = true;
        }

        // Only redraw the Raw layer. This is key to have low-CPU UI widgets that can
        // still render on the PBR layer.
        // Note: You can further improve CPU usage by not redrawing if the displayed data
        // has been only zeroes for a while.
        if (needRedraw)
            setDirtyWhole(UILayer.rawOnly);
    }

    override void onDrawRaw(ImageRef!RGBA rawMap, box2i[] dirtyRects)
    {
        foreach (dirtyRect; dirtyRects)
        {
            auto cRaw = rawMap.cropImageRef(dirtyRect);
            canvas.initialize(cRaw);
            canvas.translate(-dirtyRect.min.x, -dirtyRect.min.y);

            /// draw waveform
            for (int i=0; i<SAMPLES_TO_DISPLAY; i++)
                _stateToDisplay[i] = _inputStateToDisplay.opIndex(i);
            _drawWaveform(_stateToDisplay, RGBA(102,153,255,200));

            for (int i=0; i<SAMPLES_TO_DISPLAY; i++)
                _stateToDisplay[i] = _outputStateToDisplay.opIndex(i);
            _drawWaveform(_stateToDisplay, RGBA(153,102,255,200));
        }
    }

    void _drawWaveform(float[] stateToDisplay, RGBA fillStyle)
    {
        float W = position.width;
        float H = position.height;
        float center = H * 0.5f;
        float wavChunkWidth = W / SAMPLES_TO_DISPLAY;

        canvas.fillStyle = fillStyle;
        canvas.beginPath();
        canvas.moveTo(0,center);
        for (int i=0; i<SAMPLES_TO_DISPLAY; i++)
        {
            float sample = stateToDisplay[i];
            float maxH = center - sample * H/2;
            //float minH = center + sample * H/2;
            float chunkX = i * wavChunkWidth;
            canvas.lineTo(chunkX,maxH);
        }
        canvas.lineTo(W,center);

        for (int i=SAMPLES_TO_DISPLAY-1; i>=0; i--)
        {
            float sample = stateToDisplay[i];
            float minH = center + sample * H/2;
            float chunkX = i * wavChunkWidth;
            canvas.lineTo(chunkX,minH);
        }
        canvas.closePath();
        canvas.fill();
    }

    void sendFeedbackToUI(float max_input, float max_output, int frames, float sampleRate)
    {
        /// simulate 512 samples -> 2.7s for 48kHz and FIFO of 512 samples
        assert(frames <= 512);

        if (_inputTempBuffer.accumulate(max_input,frames))
            _inputFIFO.pushData(_inputTempBuffer.nextBuffer(), sampleRate);
        if (_outputTempBuffer.accumulate(max_output,frames))
            _outputFIFO.pushData(_outputTempBuffer.nextBuffer(), sampleRate);
    }

private:
    Canvas canvas;
    TimedFIFO!float _inputFIFO;
    TimedFIFO!float _outputFIFO;
    float[SAMPLES_IN_FIFO] _inputTempState;
    float[SAMPLES_IN_FIFO] _outputTempState;
    MaxTrackerBuffer _inputTempBuffer;
    MaxTrackerBuffer _outputTempBuffer;
    RingBufferNoGC!float _inputStateToDisplay;
    RingBufferNoGC!float _outputStateToDisplay;
    float[SAMPLES_TO_DISPLAY] _stateToDisplay;
}

struct MaxTrackerBuffer
{
public:
nothrow:
@nogc:

    bool accumulate(float sample, int frames)
    {
        if (_frameCounter==0 || sample > _maxTracker)
            _maxTracker = sample;
        _frameCounter += frames;
        if (_frameCounter >= _bufferSize)
        {
            _isReady = true;
            _max = _maxTracker;
            _maxTracker = -140.0f;
            _frameCounter = 0;
        }
        return _isReady;
    }

    float nextBuffer()
    {
        return _max;
    }

private:
    int _bufferSize = 512;
    int _frameCounter = 0;
    float _maxTracker = -140.0f;
    bool _isReady = false;
    float _max = -140.0f;

}
