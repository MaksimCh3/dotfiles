class Point(val x: Float, val y: Float, val time: Long) {
    fun rateFromPoint(start: Point) =
        sqrt((x - start.x).toDouble().pow(2.0) + (y - start.y).toDouble().pow(2.0)).toFloat() / (time - start.time)
}

class SignatureView(context: Context, attrs: AttributeSet?) : View(context, attrs) {
    companion object {
        private const val MIN_STROKE_WIDTH = 1f
        private const val MIN_INCREMENT = 0.01f
        private const val INCREMENT_CONSTANT = 0.0005f
        private const val DRAWING_CONSTANT = 0.0085f
        private const val MAX_RATE_BOUND = 15f
        private const val MIN_RATE_BOUND = 1.6f
        private const val STROKE_DES_RATE = 1.0f
        private const val RATE_FILTER_WEIGHT = 0.2f
    }

    private var previousPoint: Point? = null
    private var startPoint: Point? = null
    private var currentPoint: Point? = null
    private var lastRate = 0f
    private var lastWidth = 0f
    private var canvasBitmap: Canvas? = null
    private var ignoreTouch = false
    private var layoutLeft = 0
    private var layoutTop = 0
    private var layoutRight = 0
    private var layoutBottom = 0
    private val paint = Paint().apply {
        color = ContextCompat.getColor(context, R.color.penRoyalBlue)
        isAntiAlias = true
        style = Style.FILL_AND_STROKE
        strokeJoin = Join.ROUND
        strokeCap = Cap.ROUND
        strokeWidth = 12f
    }
    private var bitmap: Bitmap? = null
    private var drawViewRect: Rect? = null
    var paintLineStrokeWidth = paint.strokeWidth

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        layoutLeft = left
        layoutTop = top
        layoutRight = right
        layoutBottom = bottom
        if (bitmap == null) createEmptyBitmapCanvas(layoutLeft, layoutTop, layoutRight, layoutBottom)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                ignoreTouch = false
                drawViewRect = Rect(left, top, right, bottom)
                onTouchDownEvent(event.x, event.y)
            }
            MotionEvent.ACTION_MOVE -> if (!drawViewRect!!.contains(left + event.x.toInt(), top)) {
                if (!ignoreTouch) {
                    ignoreTouch = true
                    onTouchUpEvent(event.x, event.y)
                }
            } else {
                if (ignoreTouch) {
                    ignoreTouch = false
                    onTouchDownEvent(event.x, event.y)
                } else
                    onTouchMoveEvent(event.x, event.y)
            }
            MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_UP -> onTouchUpEvent(event.x, event.y)
        }
        return true
    }

    override fun onDraw(canvas: Canvas) {
        canvas.drawBitmap(bitmap!!, 0f, 0f, null)
    }

    fun clearCanvas() {
        previousPoint = null
        startPoint = null
        currentPoint = null
        lastRate = 0f
        lastWidth = 0f
        createEmptyBitmapCanvas(layoutLeft, layoutTop, layoutRight, layoutBottom)
        postInvalidate()
    }

    private fun createEmptyBitmapCanvas(left: Int, top: Int, right: Int, bottom: Int) {
        bitmap = null
        canvasBitmap = null
        if (right - left > 0 && bottom - top > 0) {
            bitmap = Bitmap.createBitmap(right - left, bottom - top, Bitmap.Config.ARGB_8888)
            canvasBitmap = Canvas(bitmap!!)
            canvasBitmap!!.drawColor(Color.WHITE)
        }
    }

    private fun onTouchDownEvent(x: Float, y: Float) {
        previousPoint = null
        startPoint = null
        currentPoint = null
        lastRate = 0f
        lastWidth = paintLineStrokeWidth
        currentPoint = Point(x, y, System.currentTimeMillis())
        previousPoint = currentPoint
        startPoint = previousPoint
        postInvalidate()
    }

    private fun onTouchMoveEvent(x: Float, y: Float) {
        if (previousPoint == null) return
        startPoint = previousPoint
        previousPoint = currentPoint
        currentPoint = Point(x, y, System.currentTimeMillis())
        var rate = currentPoint!!.rateFromPoint(previousPoint!!)
        rate = RATE_FILTER_WEIGHT * rate + (1 - RATE_FILTER_WEIGHT) * lastRate
        val strokeWidth = getStrokeWidth(rate)
        drawLine(lastWidth, strokeWidth, rate)
        lastRate = rate
        lastWidth = strokeWidth
        postInvalidate()
    }

    private fun onTouchUpEvent(x: Float, y: Float) {
        if (previousPoint == null) return
        startPoint = previousPoint
        previousPoint = currentPoint
        currentPoint = Point(x, y, System.currentTimeMillis())
        drawLine(lastWidth, 0f, lastRate)
        postInvalidate()
    }

    private fun getStrokeWidth(rate: Float) = (paintLineStrokeWidth - rate * STROKE_DES_RATE)

    private fun drawLine(lastWidth: Float, currentWidth: Float, rate: Float) {
        val firstMidPoint = getMidPoint(previousPoint, startPoint)
        val secondMidPoint = getMidPoint(currentPoint, previousPoint)

        if (canvasBitmap != null) {
            var firstMidCoordX: Float
            var secondMidCoordX: Float
            var firstMidCoordY: Float
            var secondMidCoordY: Float
            var x: Float
            var y: Float
            val increment: Float = if (rate > MIN_RATE_BOUND && rate < MAX_RATE_BOUND)
                DRAWING_CONSTANT - rate * INCREMENT_CONSTANT
            else
                MIN_INCREMENT
            var i = 0f
            while (i < 1f) {
                firstMidCoordX = getPt(firstMidPoint.x, previousPoint!!.x, i)
                firstMidCoordY = getPt(firstMidPoint.y, previousPoint!!.y, i)
                secondMidCoordX = getPt(previousPoint!!.x, secondMidPoint.x, i)
                secondMidCoordY = getPt(previousPoint!!.y, secondMidPoint.y, i)
                x = getPt(firstMidCoordX, secondMidCoordX, i)
                y = getPt(firstMidCoordY, secondMidCoordY, i)
                val strokeWidth = lastWidth + (currentWidth - lastWidth) * i
                paint.strokeWidth = if (strokeWidth < MIN_STROKE_WIDTH) MIN_STROKE_WIDTH else strokeWidth
                canvasBitmap!!.drawPoint(x, y, paint)
                i += increment
            }
        }
    }

    private fun getPt(firstCoordinate: Float, secondCoordinate: Float, percentage: Float) =
        firstCoordinate + (secondCoordinate - firstCoordinate) * percentage

    private fun getMidPoint(firstPoint: Point?, secondPoint: Point?) = Point(
        (firstPoint!!.x + secondPoint!!.x) / 2.0f,
        (firstPoint.y + secondPoint.y) / 2,
        (firstPoint.time + secondPoint.time) / 2
    )
}
