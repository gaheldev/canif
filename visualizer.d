module visualizer;

import core.stdc.stdio;

import gui;

import core.atomic;
import dplug.core;
import dplug.gui;
import dplug.canvas;
import dplug.client;

import std.algorithm;

/// This widgets demonstrates how to:
/// - do a custom widget
/// - use dplug:canvas
/// - use TimedFIFO for UI feedback with sub-buffer latency
/// - render to both the Raw and PBR layer
/// For more custom widget tips, see "Dplug Tutorials 3 - Anatomy of a custom widget".

/// Displays input and clipped output with clipper threshold
final class UIVisualizer : UIElement, IParameterListener
{
public:
nothrow:
@nogc:

    enum SAMPLES_IN_FIFO = 256;
    enum INPUT_SUBSAMPLING = 1;
    enum READ_OVERSAMPLING = 256;

    this(UIContext context, Parameter clippingAmount)
    {
        super(context, flagRaw | flagAnimated);
        _clippingAmount = cast(FloatParameter) clippingAmount;
        _clippingAmount.addListener(this);
        _inputFIFO.initialize(SAMPLES_IN_FIFO,INPUT_SUBSAMPLING);
        _outputFIFO.initialize(SAMPLES_IN_FIFO,INPUT_SUBSAMPLING);
        _inputStateToDisplay[] = 0.0f;
        _outputStateToDisplay[] = 0.0f;
    }

    ~this()
    {
        _clippingAmount.removeListener(this);
    }

    override void onAnimate(double dt, double time)
    {
        bool needRedraw = false;
        int nbSamples = _inputFIFO.readOldestDataAndDropSome(_inputStateToDisplay[], dt, READ_OVERSAMPLING);
        _outputFIFO.readOldestDataAndDropSome(_outputStateToDisplay[], dt, READ_OVERSAMPLING);
        if (nbSamples)
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
        float W = position.width;
        float H = position.height;
        float center = H * 0.5f;

        float lineWidth = H * 0.01f;
        float lineH = (center-lineWidth) * _clippingAmount.getNormalized();

        foreach (dirtyRect; dirtyRects)
        {
            auto cRaw = rawMap.cropImageRef(dirtyRect);
            canvas.initialize(cRaw);
            canvas.translate(-dirtyRect.min.x, -dirtyRect.min.y);

            // Fill with dark color
            canvas.fillStyle = "rgba(238, 124, 62, 90%)";
            canvas.fillRect(0, lineH, W, lineWidth);
            canvas.fillRect(0, H-lineH, W, -lineWidth);

            /// draw waveform
            _drawWaveform(_inputStateToDisplay[], RGBA(102,153,255,200));
            _drawWaveform(_outputStateToDisplay[], RGBA(153,102,255,200));
        }
    }

    void _drawWaveform(float[] stateToDisplay, RGBA fillStyle)
    {
        float W = position.width;
        float H = position.height;
        float center = H * 0.5f;
        float wavChunkWidth = W / READ_OVERSAMPLING;

        canvas.fillStyle = fillStyle;
        for (int i=0; i<READ_OVERSAMPLING; i++)
        {
            float sample = stateToDisplay[i];
            float maxH = center - sample * H/2;
            float minH = center + sample * H/2;
            float chunkX = i * wavChunkWidth;

            canvas.fillRect(chunkX, maxH, wavChunkWidth, minH-maxH);
        }
    }

    override void onParameterChanged(Parameter sender)
    {
        setDirtyWhole();
    }

    override void onBeginParameterEdit(Parameter sender)
    {
        setDirtyWhole();
    }

    override void onEndParameterEdit(Parameter sender)
    {
        setDirtyWhole();
    }

    void sendFeedbackToUI(float max_input, float max_output, int frames, float sampleRate)
    {
        /// simulate 512 samples -> 9.8s for 48kHz and FIFO of 1024 samples
        assert(frames <= 512);
        int nbDuplicates = 512 / frames;

        for (int i=0; i<nbDuplicates; i++)
        {
            _inputFIFO.pushData(max_input, sampleRate);
            _outputFIFO.pushData(max_output, sampleRate);
        }
    }

private:
    Canvas canvas;
    FloatParameter _clippingAmount;
    TimedFIFO!float _inputFIFO;
    TimedFIFO!float _outputFIFO;
    float[READ_OVERSAMPLING] _inputStateToDisplay;
    float[READ_OVERSAMPLING] _outputStateToDisplay;
}
