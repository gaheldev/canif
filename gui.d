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
import widgets.flattoggle;

class ClipperGUI : FlatBackgroundGUI!("background.png",

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
        super( makeSizeConstraintsDiscrete(920, 480, ratios) );

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
        OwnedImage!RGBA softenOnImage = loadOwnedImage(cast(ubyte[])(import("softenOn.png")));
        OwnedImage!RGBA softenOnHoverImage = loadOwnedImage(cast(ubyte[])(import("softenOnHover.png")));
        OwnedImage!RGBA softenOffImage = loadOwnedImage(cast(ubyte[])(import("softenOff.png")));
        OwnedImage!RGBA softenOffHoverImage = loadOwnedImage(cast(ubyte[])(import("softenOffHover.png")));
        /* OwnedImage!RGBA switchOnImage = loadOwnedImage(cast(ubyte[])(import("switchOn.png"))); */
        /* OwnedImage!RGBA switchOffImage = loadOwnedImage(cast(ubyte[])(import("switchOff.png"))); */

        // Creates all widets and adds them as children to the GUI
        // widgets are not visible until their positions have been set
        int numFrames = 101;

        _outputGainKnob = mallocNew!UIFilmstripKnob(context(), 
                                                    cast(FloatParameter) _client.param(paramOutputGain),
                                                    knobImage, 
                                                    numFrames);
        addChild(_outputGainKnob);

        _mixKnob = mallocNew!UIFilmstripKnob(context(), 
                                             cast(FloatParameter) _client.param(paramMix),
                                             knobImage, 
                                             numFrames);
        addChild(_mixKnob);


        _waveforms = mallocNew!UIWaveforms(context());
        addChild(_waveforms);

        _cliplines = mallocNew!UICliplines(context(), cast(FloatParameter) _client.param(paramClip));
        addChild(_cliplines);

        addChild(_modeToggle = mallocNew!UIImageToggle(context(), cast(BoolParameter) _client.param(paramMode), 
                                                       softenOnImage, softenOnHoverImage,
                                                       softenOffImage, softenOffHoverImage));       

        addChild(_resizerHint = mallocNew!UIWindowResizer(context()));        
    }

    ~this()
    {
        _knobImageData.destroyFree();
    }

    override void reflow()
    {
        super.reflow();

        int W = position.width;
        int H = position.height;

        float S = W / cast(float)(context.getDefaultUIWidth());

        /* _clipKnob.position       = rectangle(840, 246, 120, 120).scaleByFactor(S); */
        _outputGainKnob.position = rectangle(270, 408, 60, 60).scaleByFactor(S);
        _mixKnob.position        = rectangle(404, 408, 60, 60).scaleByFactor(S);

        /* RGBA litTrailColor = RGBA(144,192,193,165); */
        /* _clipKnob.litTrailDiffuse  = litTrailColor; */
        /* _outputGainKnob.litTrailDiffuse  = litTrailColor; */
        /* _mixKnob.litTrailDiffuse  = litTrailColor; */

        /* RGBA unlitTrailColor = RGBA(103,129,129,8); */
        /* _clipKnob.unlitTrailDiffuse  = unlitTrailColor; */
        /* _outputGainKnob.unlitTrailDiffuse  = unlitTrailColor; */
        /* _mixKnob.unlitTrailDiffuse  = unlitTrailColor; */

        _waveforms.position = rectangle(30, 76, 770, 268).scaleByFactor(S);
        _cliplines.position = rectangle(30, 76, 770, 268).scaleByFactor(S);
 
        _modeToggle.position = rectangle(826, 79, 78, 29).scaleByFactor(S);
        _resizerHint.position = rectangle(W-30, H-30, 30, 30);
    }

    void sendFeedbackToUI(float max_input, float max_output, int frames, float sampleRate)
    {
        _waveforms.sendFeedbackToUI(max_input, max_output, frames, sampleRate);
    }


private:
    KnobImage _knobImageData;
    /* UIImageKnob _clipKnob; */
    UIFilmstripKnob _outputGainKnob;
    UIFilmstripKnob _mixKnob;
    UIImageToggle   _modeToggle;
    UIWindowResizer _resizerHint;
    UIWaveforms     _waveforms;
    UICliplines     _cliplines;
}
