module cliplines;

import core.stdc.stdio;

import gui;

import core.atomic;
import dplug.core;
import dplug.gui;
import dplug.canvas;
import dplug.client;

/// Displays clipper threshold
final class UICliplines : UIElement, IParameterListener
{
public:
nothrow:
@nogc:

    this(UIContext context, Parameter clippingAmount)
    {
        super(context, flagRaw);
        _clippingAmount = cast(FloatParameter) clippingAmount;
        _clippingAmount.addListener(this);
    }

    ~this()
    {
        _clippingAmount.removeListener(this);
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

            canvas.fillStyle = "rgba(238, 124, 62, 90%)";
            canvas.fillRect(0, lineH, W, lineWidth);
            canvas.fillRect(0, H-lineH, W, -lineWidth);
        }
    }

    override void onParameterChanged(Parameter sender)
    {
        setDirtyWhole(UILayer.rawOnly);
    }

    override void onBeginParameterEdit(Parameter sender)
    {
        setDirtyWhole(UILayer.rawOnly);
    }

    override void onEndParameterEdit(Parameter sender)
    {
        setDirtyWhole(UILayer.rawOnly);
    }

private:
    Canvas canvas;
    FloatParameter _clippingAmount;
}
