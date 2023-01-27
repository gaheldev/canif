/**
Film-strip on/off switch.

Copyright: Ethan Reker 2017.
Copyright: Guillaume Piolat 2018.
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module widgets.flattoggle;

import std.math;
import dplug.core.math;
import dplug.gui.element;
import dplug.client.params;

class UIImageToggle : UIElement, IParameterListener
{
public:
nothrow:
@nogc:

    enum Orientation
    {
        vertical,
        horizontal
    }

    @ScriptProperty
    {
        Orientation orientation = Orientation.vertical;
    }

    this(UIContext context, BoolParameter param, 
         OwnedImage!RGBA onImage, OwnedImage!RGBA onHoverImage,
         OwnedImage!RGBA offImage, OwnedImage!RGBA offHoverImage)
    {
        super(context, flagRaw);
        _param = param;
        _param.addListener(this);

        _onImage = onImage;
        _onHoverImage = onHoverImage;
        _offImage = offImage;
        _offHoverImage = offHoverImage;
        assert(_onImage.h == _offImage.h);
        assert(_onImage.w == _offImage.w);
        assert(_onHoverImage.h == _offHoverImage.h);
        assert(_onHoverImage.w == _offHoverImage.w);
        assert(_onImage.h == _offHoverImage.h);
        assert(_onImage.w == _offHoverImage.w);
        _width = _onImage.w;
        _height = _onImage.h;

        _hover = false;

        _onImageScaled = mallocNew!(OwnedImage!RGBA)();
        _onHoverImageScaled = mallocNew!(OwnedImage!RGBA)();
        _offImageScaled = mallocNew!(OwnedImage!RGBA)();
        _offHoverImageScaled = mallocNew!(OwnedImage!RGBA)();
    }

    ~this()
    {
        _param.removeListener(this);
        _onImageScaled.destroyFree();
        _onHoverImageScaled.destroyFree();
        _offImageScaled.destroyFree();
        _offHoverImageScaled.destroyFree();
    }

    bool getState()
    {
      return unsafeObjectCast!BoolParameter(_param).valueAtomic();
    }

    override void reflow()
    {
        _onImageScaled.size(position.width, position.height);
        _onHoverImageScaled.size(position.width, position.height);
        _offImageScaled.size(position.width, position.height);
        _offHoverImageScaled.size(position.width, position.height);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_onImage.toRef, _onImageScaled.toRef);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_onHoverImage.toRef, _onHoverImageScaled.toRef);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_offImage.toRef, _offImageScaled.toRef);
        context.globalImageResizer.resizeImage_sRGBWithAlpha(_offHoverImage.toRef, _offHoverImageScaled.toRef);
    }

    override void onDrawRaw(ImageRef!RGBA rawMap, box2i[] dirtyRects)
    {
        OwnedImage!RGBA _currentImage;
        if(_hover)
        {
            _currentImage = getState() ? _onHoverImageScaled : _offHoverImageScaled;
        }
        else
        {
            _currentImage = getState() ? _onImageScaled : _offImageScaled;
        }

        foreach(dirtyRect; dirtyRects)
        {
            auto croppedRawIn = _currentImage.toRef.cropImageRef(dirtyRect);
            auto croppedRawOut = rawMap.cropImageRef(dirtyRect);

            int w = dirtyRect.width;
            int h = dirtyRect.height;

            for(int j = 0; j < h; ++j)
            {
                RGBA[] input = croppedRawIn.scanline(j);
                RGBA[] output = croppedRawOut.scanline(j);

                for(int i = 0; i < w; ++i)
                {
                    ubyte alpha = input[i].a;

                    RGBA color = blendColor(input[i], output[i], alpha);
                    output[i] = color;
                }
            }
        }
    }

    override Click onMouseClick(int x, int y, int button, bool isDoubleClick, MouseState mstate)
    {
        if (mstate.altPressed) // reset on ALT + click
        {
            _param.beginParamEdit();
            _param.setFromGUI(_param.defaultValue());
            _param.endParamEdit();
        }
        else
        {
            // Any click => invert
            // Note: double-click doesn't reset to default, would be annoying
            _param.beginParamEdit();
            _param.setFromGUI(!_param.value());
            _param.endParamEdit();
        }
        return Click.startDrag; 
    }

    override void onMouseEnter()
    {
        _param.beginParamHover();
        setDirtyWhole();
        _hover = true;
    }

    override void onMouseMove(int x, int y, int dx, int dy, MouseState mstate)
    {        
    }

    override void onMouseExit()
    {
        _param.endParamHover();
        setDirtyWhole();
        _hover = false;
    }

    override void onBeginDrag()
    {
    }

    override void onStopDrag()
    {
    }
    
    override void onMouseDrag(int x, int y, int dx, int dy, MouseState mstate)
    {        
    }

    override void onParameterChanged(Parameter sender) nothrow @nogc
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

    BoolParameter _param;
    bool _hover;
    OwnedImage!RGBA _onImage;
    OwnedImage!RGBA _onHoverImage;
    OwnedImage!RGBA _offImage;
    OwnedImage!RGBA _offHoverImage;
    OwnedImage!RGBA _onImageScaled;
    OwnedImage!RGBA _onHoverImageScaled;
    OwnedImage!RGBA _offImageScaled;
    OwnedImage!RGBA _offHoverImageScaled;
    int _width;
    int _height;
}

