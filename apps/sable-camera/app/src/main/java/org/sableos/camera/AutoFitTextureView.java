package org.sableos.camera;

import android.content.Context;
import android.util.AttributeSet;
import android.view.TextureView;

final class AutoFitTextureView extends TextureView {
    private int ratioWidth;
    private int ratioHeight;

    AutoFitTextureView(Context context) {
        super(context);
    }

    AutoFitTextureView(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    void setAspectRatio(int width, int height) {
        if (width <= 0 || height <= 0) {
            throw new IllegalArgumentException("Aspect ratio dimensions must be positive");
        }
        ratioWidth = width;
        ratioHeight = height;
        requestLayout();
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = MeasureSpec.getSize(widthMeasureSpec);
        int height = MeasureSpec.getSize(heightMeasureSpec);

        if (ratioWidth == 0 || ratioHeight == 0) {
            setMeasuredDimension(width, height);
            return;
        }

        if ((long) width * ratioHeight < (long) height * ratioWidth) {
            setMeasuredDimension(
                    width,
                    width * ratioHeight / ratioWidth
            );
        } else {
            setMeasuredDimension(
                    height * ratioWidth / ratioHeight,
                    height
            );
        }
    }
}
