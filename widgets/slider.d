/**
Film-strip slider.

Copyright: Guillaume Piolat 2015-2018.
Copyright: Ethan Reker 2017.
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module widgets.slider;

import std.math;
import std.algorithm.comparison;

import dplug.core.math;
import dplug.gui.bufferedelement;
import dplug.client.params;

class UIFlatSlider : UIElement, IParameterListener
{
public:
nothrow:
@nogc:

    enum Direction
    {
        vertical,
        horizontal
    }

    @ScriptProperty Direction direction = Direction.vertical;

    this(UIContext context, 
            LinearFloatParameter param, 
            OwnedImage!RGBA sliderImage, 
            OwnedImage!RGBA sliderHoverImage,
            OwnedImage!RGBA sliderGrabImage,
            float sensitivity = 0.25)
    {
        super(context, flagRaw);
        _param = param;
        _param.addListener(this);
        _sensivity = sensitivity;

        _slider = sliderImage;
        _sliderHover = sliderHoverImage;
        _sliderGrab = sliderGrabImage;
        assert(_slider.h == _sliderHover.h);
        assert(_slider.w == _sliderHover.w);
        assert(_slider.h == _sliderGrab.h);
        assert(_slider.w == _sliderGrab.w);
        _width = _slider.w;
        _height = _slider.h;

        _hover = false;
        _hold = false;

        _sliderScaled = mallocNew!(OwnedImage!RGBA)();
        _sliderHoverScaled = mallocNew!(OwnedImage!RGBA)();
        _sliderGrabScaled = mallocNew!(OwnedImage!RGBA)();
    }

    ~this()
    {
        _param.removeListener(this);
        _sliderScaled.destroyFree();
        _sliderHoverScaled.destroyFree();
        _sliderGrabScaled.destroyFree();
    }

    /// Returns: sensivity.
    float sensivity()
    {
        return _sensivity;
    }

    /// Sets sensivity.
    float sensivity(float sensivity)
    {
        return _sensivity = sensivity;
    }

    override void onDrawRaw(ImageRef!RGBA rawMap, box2i[] dirtyRects)
    {
        OwnedImage!RGBA _currentImage;
        if(_hold)
            _currentImage = _sliderGrabScaled;
        else if(_hover)
            _currentImage = _sliderHoverScaled;
        else
            _currentImage = _sliderScaled;

        foreach(dirtyRect; dirtyRects)
        {
            ImageRef!RGBA croppedRawIn = _currentImage.toRef.cropImageRef(dirtyRect);
            ImageRef!RGBA croppedRawOut = rawMap.cropImageRef(dirtyRect);

            int w = dirtyRect.width;
            int h = dirtyRect.height;

            for(int j = 0; j < h; ++j)
            {
                RGBA[] input = croppedRawIn.scanline(j);
                RGBA[] output = croppedRawOut.scanline(j);

                for(int i = 0; i < w; ++i)
                {
                    ubyte alpha = input[i].a;
                    output[i] = blendColor(input[i], output[i], alpha);
                }
            }
        }
    }

    override void reflow()
    {
        int W = position.width;
        int H = position.height;
        _sliderScaled.size(W,H);
        _sliderHoverScaled.size(W,H);
        _sliderGrabScaled.size(W,H);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_slider.toRef, _sliderScaled.toRef);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_sliderHover.toRef, _sliderHoverScaled.toRef);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_sliderGrab.toRef, _sliderGrabScaled.toRef);
    }  

    override Click onMouseClick(int x, int y, int button, bool isDoubleClick, MouseState mstate)
    {
        // double-click => set to default
        if (isDoubleClick || mstate.altPressed)
        {
            _param.beginParamEdit();
            _param.setFromGUI(_param.defaultValue());
            _param.endParamEdit();
        }

        return Click.startDrag; // to initiate dragging
    }

    // Called when mouse drag this Element.
    override void onMouseDrag(int x, int y, int dx, int dy, MouseState mstate)
    {
        /* // FUTURE: replace by actual trail height instead of total height */
        /* float referenceCoord; */
        /* float displacementInHeight; */
        /* if (direction == Direction.vertical) */
        /* { */
        /*     referenceCoord = y; */
        /*     displacementInHeight = cast(float)(dy) / _position.height; */
        /* } */
        /* else */
        /* { */
        /*     referenceCoord = -x; */
        /*     displacementInHeight = cast(float)(-dx) / _position.width; */
        /* } */
        /*  */
        /* float modifier = 1.0f; */
        /* if (mstate.shiftPressed || mstate.ctrlPressed) */
        /*     modifier *= 0.1f; */
        /*  */
        /* double oldParamValue = _param.getNormalized(); */
        /* double newParamValue = oldParamValue - displacementInHeight * modifier * _sensivity; */
        /* if (mstate.altPressed) */
        /*     newParamValue = _param.getNormalizedDefault(); */
        /*  */
        /* if (referenceCoord > _mousePosOnLast0Cross) */
        /*     return; */
        /* if (referenceCoord < _mousePosOnLast1Cross) */
        /*     return; */
        /*  */
        /* if (newParamValue <= 0 && oldParamValue > 0) */
        /*     _mousePosOnLast0Cross = referenceCoord; */
        /*  */
        /* if (newParamValue >= 1 && oldParamValue < 1) */
        /*     _mousePosOnLast1Cross = referenceCoord; */
        /*  */
        /* if (newParamValue < 0) */
        /*     newParamValue = 0; */
        /* if (newParamValue > 1) */
        /*     newParamValue = 1; */
        /*  */
        /* if (newParamValue > 0) */
        /*     _mousePosOnLast0Cross = float.infinity; */
        /*  */
        /* if (newParamValue < 1) */
        /*     _mousePosOnLast1Cross = -float.infinity; */
        /*  */
        /* if (newParamValue != oldParamValue) */
        /* { */
        /*     if (auto p = cast(FloatParameter)_param) */
        /*     { */
        /*         p.setFromGUINormalized(newParamValue); */
        /*     } */
        /*     else */
        /*         assert(false); // only integer and float parameters supported */
        /* } */
        /* setDirtyWhole(); */
    }

    // For lazy updates
    override void onBeginDrag()
    {
        _param.beginParamEdit();
        setDirtyWhole();
        _hold = true;
    }

    override void onStopDrag()
    {
        _param.endParamEdit();
        setDirtyWhole();
        _hold = false;
    }

    override void onMouseEnter()
    {
        _param.beginParamHover();
        setDirtyWhole();
        _hover = true;
    }

    override void onMouseExit()
    {
        _param.endParamHover();
        setDirtyWhole();
        _hover = false;
    }

    override void onParameterChanged(Parameter sender)
    {
        setDirtyWhole();
    }

    override void onBeginParameterEdit(Parameter sender)
    {
    }

    override void onEndParameterEdit(Parameter sender)
    {
    }

    override void onBeginParameterHover(Parameter sender)
    {
    }

    override void onEndParameterHover(Parameter sender)
    {
    }


protected:

    /// The parameter this switch is linked with.
    LinearFloatParameter _param;

    bool _hover;
    bool _hold;

    int _width;
    int _height;

    OwnedImage!RGBA _slider;
    OwnedImage!RGBA _sliderHover;
    OwnedImage!RGBA _sliderGrab;

    OwnedImage!RGBA _sliderScaled;
    OwnedImage!RGBA _sliderHoverScaled;
    OwnedImage!RGBA _sliderGrabScaled;

    /// Sensivity: given a mouse movement in 100th of the height of the knob,
    /// how much should the normalized parameter change.
    float _sensivity;

    float _mousePosOnLast0Cross;
    float _mousePosOnLast1Cross;

    ImageResizer _resizer;

    void clearCrosspoints()
    {
        _mousePosOnLast0Cross = float.infinity;
        _mousePosOnLast1Cross = -float.infinity;
    }
}
