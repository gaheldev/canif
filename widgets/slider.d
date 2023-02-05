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

import dplug.graphics.color;

class UIFlatSlider : UIElement, IParameterListener
{
public:
nothrow:
@nogc:

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

        _width = position.width;
        _height = position.height;

        _handle = sliderImage;
        _handleHover = sliderHoverImage;
        _handleGrab = sliderGrabImage;
        assert(_handle.h == _handleHover.h);
        assert(_handle.w == _handleHover.w);
        assert(_handle.h == _handleGrab.h);
        assert(_handle.w == _handleGrab.w);

        _hover = false;
        _hold = false;

        _sliderImage = mallocNew!(OwnedImage!RGBA)();

        _handleScaled = mallocNew!(OwnedImage!RGBA)();
        _handleHoverScaled = mallocNew!(OwnedImage!RGBA)();
        _handleGrabScaled = mallocNew!(OwnedImage!RGBA)();
    }

    ~this()
    {
        _param.removeListener(this);
        _sliderImage.destroyFree();
        _handleScaled.destroyFree();
        _handleHoverScaled.destroyFree();
        _handleGrabScaled.destroyFree();
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

    void drawSliderImage(float y)
    {
        OwnedImage!RGBA _currentHandleImage;
        if(_hold)
            _currentHandleImage = _handleGrabScaled;
        else if(_hover)
            _currentHandleImage = _handleHoverScaled;
        else
            _currentHandleImage = _handleScaled;
        
        int handleStartingLineY = cast(int) y;
        int handleEndingLineY = handleStartingLineY + _currentHandleImage.h;

        // slider bar is 7px wide
        // we want to center it compared to the image width and color it below the clip handle
        // -> from 9px/25px to 16px/25px
        int barStartRow = 9 * position.width / 25;
        int barEndRow = 16 * position.width / 25;

        // last 4 pixels are already colored in background for a nice rounded effect
        // 4 pixels / 224 pixels
        int bottomRoundedCornerLine = position.height - 4 * position.height / 224;

        for(int j = 0; j < position.height; ++j)
        {
            RGBA[] output = _sliderImage.scanline(j);
            ulong w = position.width;
            if (j < handleStartingLineY)
            {
                output[0..w] = alpha;
            }
            else if (j >= handleEndingLineY && j < bottomRoundedCornerLine)
            {
                output[0..barStartRow] = alpha;
                output[barStartRow..barEndRow] = trailColor;
                output[barEndRow..w] = alpha; 
            }
            else if (j >= handleEndingLineY && j >= bottomRoundedCornerLine)
            {
                output[0..w] = alpha;
            }
            else
            {
                RGBA[] input = _currentHandleImage.scanline(j-handleStartingLineY);
                output[0..w] = input[0..w];
            }
        }
    }

    override void onDrawRaw(ImageRef!RGBA rawMap, box2i[] dirtyRects)
    {
        /* float yMin = cast(float) position.min.y; */
        /* float yMax = cast(float) position.max.y; */
        /* float y = (1 - _param.getNormalized()) * (yMax - yMin) + yMin; */
        float y = (1 - _param.getNormalized()) * cast(float) (position.height - _handleScaled.h);

        drawSliderImage(y);

        foreach(dirtyRect; dirtyRects)
        {
            ImageRef!RGBA croppedRawIn = _sliderImage.toRef.cropImageRef(dirtyRect);
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
        _sliderImage.size(position.width,position.height);

        int W = position.width;
        _handleScaled.size(W,W);
        _handleHoverScaled.size(W,W);
        _handleGrabScaled.size(W,W);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_handle.toRef, _handleScaled.toRef);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_handleHover.toRef, _handleHoverScaled.toRef);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_handleGrab.toRef, _handleGrabScaled.toRef);
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
        float referenceCoord;
        float displacementInHeight;
        referenceCoord = y;
        displacementInHeight = cast(float)(dy) / position.height;
        
        float modifier = 1.0f;
        if (mstate.shiftPressed || mstate.ctrlPressed)
            modifier *= 0.1f;
        
        double oldParamValue = _param.getNormalized();
        double newParamValue = oldParamValue - displacementInHeight * modifier * _sensivity;
        if (mstate.altPressed)
            newParamValue = _param.getNormalizedDefault();
        
        if (referenceCoord > _mousePosOnLast0Cross)
            return;
        if (referenceCoord < _mousePosOnLast1Cross)
            return;
        
        if (newParamValue <= 0 && oldParamValue > 0)
            _mousePosOnLast0Cross = referenceCoord;
        
        if (newParamValue >= 1 && oldParamValue < 1)
            _mousePosOnLast1Cross = referenceCoord;
        
        if (newParamValue < 0)
            newParamValue = 0;
        if (newParamValue > 1)
            newParamValue = 1;
        
        if (newParamValue > 0)
            _mousePosOnLast0Cross = float.infinity;
        
        if (newParamValue < 1)
            _mousePosOnLast1Cross = -float.infinity;
        
        if (newParamValue != oldParamValue)
        {
            if (auto p = cast(FloatParameter)_param)
            {
                p.setFromGUINormalized(newParamValue);
            }
            else
                assert(false); // only integer and float parameters supported
        }
        setDirtyWhole();
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

    OwnedImage!RGBA _sliderImage;

    OwnedImage!RGBA _handle;
    OwnedImage!RGBA _handleHover;
    OwnedImage!RGBA _handleGrab;

    OwnedImage!RGBA _handleScaled;
    OwnedImage!RGBA _handleHoverScaled;
    OwnedImage!RGBA _handleGrabScaled;

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
    RGBA alpha = RGBA(0,0,0,0);
    RGBA trailColor = RGBA(0xdd,0xbd,0xc3,0xff);
}
