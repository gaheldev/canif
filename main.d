/**
Copyright: Guillaume Piolat 2015-2017.
Copyright: Ethan Reker 2017.
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module main;

import std.math;
import std.algorithm;

import dplug.core,
       dplug.client;

import gui;

// This define entry points for plugin formats, 
// depending on which version identifiers are defined.
mixin(pluginEntryPoints!ClipperClient);

enum : int
{
    paramBypass,
    paramSoften,
    paramClip,
    paramAutogain,
    paramOutputGain,
    paramMix,
}

enum MAX_FRAMES_IN_PROCESS = 512;


/// Example mono/stereo distortion plugin.
final class ClipperClient : dplug.client.Client
{
public:
nothrow:
@nogc:

    this()
    {
    }

    override PluginInfo buildPluginInfo()
    {
        // Plugin info is parsed from plugin.json here at compile time.
        // Indeed it is strongly recommended that you do not fill PluginInfo 
        // manually, else the information could diverge.
        static immutable PluginInfo pluginInfo = parsePluginInfo(import("plugin.json"));
        return pluginInfo;
    }

    // This is an optional overload, default is zero parameter.
    // Caution when adding parameters: always add the indices
    // in the same order as the parameter enum.
    override Parameter[] buildParameters()
    {
        auto params = makeVec!Parameter();
        params ~= mallocNew!BoolParameter(paramBypass, "bypass", false);
        params ~= mallocNew!BoolParameter(paramSoften, "soften", false);
        params ~= mallocNew!LinearFloatParameter(paramClip, "clip", "%", 0.0f, 100.0f, 0.0f) ;
        params ~= mallocNew!BoolParameter(paramAutogain, "autogain", false);
        params ~= mallocNew!LinearFloatParameter(paramOutputGain, "output gain", "db", -12.0f, 12.0f, 0.0f) ;
        params ~= mallocNew!LinearFloatParameter(paramMix, "mix", "%", 0.0f, 100.0f, 100.0f) ;
        return params.releaseData();
    }

    override LegalIO[] buildLegalIO()
    {
        auto io = makeVec!LegalIO();
        io ~= LegalIO(1, 1);
        io ~= LegalIO(2, 2);
        return io.releaseData();
    }

    // This override is optional, the default implementation will
    // have one default preset.
    override Preset[] buildPresets()
    {
        auto presets = makeVec!Preset();
        presets ~= makeDefaultPreset();
        return presets.releaseData();
    }

    // This override is also optional. It allows to split audio buffers in order to never
    // exceed some amount of frames at once.
    // This can be useful as a cheap chunking for parameter smoothing.
    // Buffer splitting also allows to allocate statically or on the stack with less worries.
    override int maxFramesInProcess()
    {
        return MAX_FRAMES_IN_PROCESS;
    }

    override void reset(double sampleRate, int maxFrames, int numInputs, int numOutputs) 
    {
        // Clear here any state and delay buffers you might have.
        assert(maxFrames <= MAX_FRAMES_IN_PROCESS); // guaranteed by audio buffer splitting

        _sampleRate = sampleRate;
    }

    override void processAudio(const(float*)[] inputs, float*[]outputs, int frames, TimeInfo info)
    {
        assert(frames <= MAX_FRAMES_IN_PROCESS); // guaranteed by audio buffer splitting

        int numInputs = cast(int)inputs.length;
        int numOutputs = cast(int)outputs.length;

        int minChan = numInputs > numOutputs ? numOutputs : numInputs;

        /// Read parameter values
        /// Convert decibel values to floating point
        float outputGain = pow(10, readParam!float(paramOutputGain) /20);

        immutable float mix = readParam!float(paramMix) / 100.0f;

        immutable bool softClip = readParam!bool(paramSoften);

        immutable bool bypass = readParam!bool(paramBypass);

        immutable bool autogain = readParam!bool(paramAutogain);

        float clipAmount;
        float clipInv;
        if(softClip)
        {
            clipAmount = readParam!float(paramClip) / 3;
            clipInv = 1 / clipAmount;
            /// TODO: compute autogain for soft clipping
        }
        else
        {
            clipAmount = 1 - (readParam!float(paramClip) / 100.0f);
            /// Clamp clipAmount to ensure it is never 0
            clipAmount = clamp(clipAmount, 0.1, 1);
            if (autogain)
                outputGain = 1 / clipAmount;
        }

        for (int chan = 0; chan < minChan; ++chan)
        {
            for (int f = 0; f < frames; ++f)
            {
                float inputSample = inputs[chan][f];

                float outputSample = inputSample;

                /// TODO: crossover between input and output
                if (bypass)
                    continue;

                if(softClip)
                {
                    if(clipAmount > 0)
                        outputSample = clipInv * atan( outputSample * clipAmount);
                }
                else
                {
                    if(outputSample > clipAmount)
                        outputSample = clipAmount;
                    if(outputSample < -clipAmount)
                        outputSample = -clipAmount;
                }

                outputs[chan][f] = ((outputSample * mix) + (inputSample * (1 - mix))) * outputGain;

            }
        }

        // fill with zero the remaining channels
        for (int chan = minChan; chan < numOutputs; ++chan)
            outputs[chan][0..frames] = 0; // D has array slices assignments and operations

        _max_input  = inputs[0][0..frames].maxElement();
        _max_output = outputs[0][0..frames].maxElement();

        /// Get access to the GUI
        if (ClipperGUI gui = cast(ClipperGUI) graphicsAcquire())
        {
            /// This is where you would update any elements in the gui
            /// such as feeding values to meters.
            gui.sendFeedbackToUI(_max_input, _max_output, frames, _sampleRate);
            graphicsRelease();
        }
    }

    override IGraphics createGraphics()
    {
        return mallocNew!ClipperGUI(this);
    }

private:
   float _sampleRate; 
   float _max_input, _max_output;
}

