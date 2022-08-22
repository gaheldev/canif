/**
Copyright: Guillaume Piolat 2015-2017
Copyright: Ethan Reker 2017
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module gui;

import dplug.gui;
import dplug.pbrwidgets;
import dplug.flatwidgets;
import dplug.client;
import dplug.canvas;

import main;
import waveforms;
import cliplines;

// Plugin GUI, based on FlatBackgroundGUI.
// This allows to use knobs rendered with Knobman
class ClipperGUI : PBRBackgroundGUI!("basecolor.png", "emissive.png", "material.png",
                                     "depth.png", "skybox_furniture.png",

                                     // In development, enter here the absolute path to the gfx directory.
                                     // This allows to reload background images at debug-time when pressing the RETURN key.
                                     `/home/myuser/my/path/to/Dplug/examples/clipit/gfx/`)
{
public:
nothrow:
@nogc:

    ClipperClient _client;

    this(ClipperClient client)
    {
        _client = client;

        static immutable float[7] ratios = [0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 1.75f, 2.0f];
        super( makeSizeConstraintsDiscrete(1000, 600, ratios) );

        // Sets the number of pixels recomputed around dirtied controls.
        // Since we aren't using PBR we can set this value to 0 to save
        // on resources.
        // If you are mixing PBR and flat elements, you may want to set this
        // to a higher value such as 20.
        setUpdateMargin(0);

        // All resources are bundled as a string import.
        // You can avoid resource compilers that way.
        // The only cost is that each resource is in each binary, this creates overhead 
        OwnedImage!RGBA knobImage = loadOwnedImage(cast(ubyte[])(import("knob.png")));
        OwnedImage!RGBA switchOnImage = loadOwnedImage(cast(ubyte[])(import("switchOn.png")));
        OwnedImage!RGBA switchOffImage = loadOwnedImage(cast(ubyte[])(import("switchOff.png")));

        // Creates all widets and adds them as children to the GUI
        // widgets are not visible until their positions have been set
        int numFrames = 101;


        _inputGainKnob = mallocNew!UIFilmstripKnob(context(), cast(FloatParameter) _client.param(paramInputGain), knobImage, numFrames);
        addChild(_inputGainKnob);
        
        _clipKnob = mallocNew!UIFilmstripKnob(context(), cast(FloatParameter) _client.param(paramClip), knobImage, numFrames);
        addChild(_clipKnob);
        
        _outputGainKnob = mallocNew!UIFilmstripKnob(context(), cast(FloatParameter) _client.param(paramOutputGain), knobImage, numFrames);
        addChild(_outputGainKnob);
        
        _mixKnob = mallocNew!UIFilmstripKnob(context(), cast(FloatParameter) _client.param(paramMix), knobImage, numFrames);
        addChild(_mixKnob);

        _waveforms = mallocNew!UIWaveforms(context());
        addChild(_waveforms);

        _cliplines = mallocNew!UICliplines(context(), cast(FloatParameter) _client.param(paramClip));
        addChild(_cliplines);

        addChild(_modeSwitch = mallocNew!UIImageSwitch(context(), cast(BoolParameter) _client.param(paramMode), switchOnImage, switchOffImage));       

        addChild(_resizerHint = mallocNew!UIWindowResizer(context()));        
    }

    override void reflow()
    {
        super.reflow();

        int W = position.width;
        int H = position.height;

        float S = W / cast(float)(context.getDefaultUIWidth());

        _inputGainKnob.position  = rectangle(840, 40, 120, 120).scaleByFactor(S);
        _clipKnob.position       = rectangle(840, 246, 120, 120).scaleByFactor(S);
        _outputGainKnob.position = rectangle(230, 524, 64, 64).scaleByFactor(S);
        _mixKnob.position        = rectangle(530, 524, 64, 64).scaleByFactor(S);

        _waveforms.position = rectangle(35, 40, 740, 428).scaleByFactor(S);
        _cliplines.position = rectangle(35, 40, 740, 428).scaleByFactor(S);
 
        _modeSwitch.position = rectangle(814, 542, 80, 34).scaleByFactor(S);
        _resizerHint.position = rectangle(W-30, H-30, 30, 30);
    }

    void sendFeedbackToUI(float max_input, float max_output, int frames, float sampleRate)
    {
        _waveforms.sendFeedbackToUI(max_input, max_output, frames, sampleRate);
    }


private:
    UIFilmstripKnob _inputGainKnob;
    UIFilmstripKnob _clipKnob;
    UIFilmstripKnob _outputGainKnob;
    UIFilmstripKnob _mixKnob;
    UIImageSwitch   _modeSwitch;
    UIWindowResizer _resizerHint;
    UIWaveforms     _waveforms;
    UICliplines     _cliplines;
}
