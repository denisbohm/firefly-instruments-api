//
//  CurrentChart.swift
//  FireflyInstruments
//
//  Created by Denis Bohm on 11/16/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

@IBDesignable open class CurrentChart: NSView {
    
    public struct Sample {
        let date: Date
        let current: Double
    }
    
    open var discontinuity = 1.0
    open var samples: [Sample] = []
    open var timeOffset: Double = 0.0
    open var timeScale: Double = 1.0
    open var currentOffset: Double = 0.0
    open var currentScale: Double = 1.0
    open var currentMax: Double = 0.02
    open var summary: String = ""
    open var dateFormatter = DateFormatter()
    open var tip: NSString = ""
    open var trackingArea: NSTrackingArea?
    open var mouseDownEvent: NSEvent?
    open var mouseDraggedEvent: NSEvent?
    open var zoomRange: (min: Double, max: Double)?
    
    override public init(frame frameRect: NSRect) {
        super.init(frame:frameRect);
        initialize()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    open func initialize() {
        dateFormatter.dateFormat =  "mm:ss.SSS"
        
        trackingArea = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        
        let now = Date()
        samples = [
            Sample(date: now, current: 0.010),
            Sample(date: now.addingTimeInterval(1), current: 0.001),
            Sample(date: now.addingTimeInterval(2), current: 0.010),
            Sample(date: now.addingTimeInterval(3), current: 0.001),
            Sample(date: now.addingTimeInterval(4), current: 0.010),
            Sample(date: now.addingTimeInterval(5), current: 0.001),
        ]
    }
    
    override open var acceptsFirstResponder: Bool {
        return true
    }
    
    open func autoCurrentRange() {
        currentMax = samples.reduce(0.0001) { max($0, $1.current) }
    }
    
    open func setSummary(summary: String) {
        self.summary = summary
        needsDisplay = true
    }
    
    open func setSamples(samples: [Sample]) {
        self.samples = samples
        autoCurrentRange()
        zoomAll()
    }
    
    open func eventToSample(event: NSEvent) -> (date: Date, current: Double) {
        let p = convert(event.locationInWindow, from: nil)
        let time = Double(p.x) / timeScale - timeOffset
        let date = Date(timeIntervalSince1970: time)
        let current = 1000.0 * (Double(p.y) / currentScale - currentOffset)
        return (date, current)
    }
    
    open func toDateString(date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    override open func mouseMoved(with event: NSEvent) {
        let (date, current) = eventToSample(event: event)
        tip = NSString(format: "%0.3f mA, %@", current, toDateString(date: date))
        
        needsDisplay = true
    }
    
    override open func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        mouseDraggedEvent = event
        
        needsDisplay = true
    }
    
    open func timeIntervalString(interval: TimeInterval) -> String {
        let milliseconds = Int(abs(interval) * 1000)
        let SSS = milliseconds % 1000
        let seconds = milliseconds / 1000
        let ss = seconds % 60
        let minutes = seconds / 60
        let mm = minutes % 60
        return "\(mm):\(ss).\(SSS)"
    }
    
    override open func mouseDragged(with event: NSEvent) {
        mouseDraggedEvent = event
        
        let (aDate, aCurrent) = eventToSample(event: mouseDownEvent!)
        let (bDate, bCurrent) = eventToSample(event: mouseDraggedEvent!)
        tip = NSString(format: "%0.3f to %0.3f (%0.3f) mA, %@ to %@ (%@)", aCurrent, bCurrent, abs(bCurrent - aCurrent), toDateString(date: aDate), toDateString(date: bDate), timeIntervalString(interval: bDate.timeIntervalSince(aDate)))
        
        needsDisplay = true
    }
    
    open func setZoom(min zoomMin: Double, max zoomMax: Double) {
        if samples.isEmpty {
            return
        }
        let fullMin = samples.first!.date.timeIntervalSince1970
        let fullMax = samples.last!.date.timeIntervalSince1970
        let zoomRangeMin = max(fullMin, min(fullMax, zoomMin))
        let zoomRangeMax = max(fullMin, min(fullMax, zoomMax))
        if zoomRangeMin >= zoomRangeMax {
            return
        }
        zoomRange = (min: zoomRangeMin, max: zoomRangeMax)
        needsDisplay = true
    }
    
    override open func mouseUp(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            let (aDate, _) = eventToSample(event: mouseDownEvent!)
            let (bDate, _) = eventToSample(event: mouseDraggedEvent!)
            let aTime = aDate.timeIntervalSince1970
            let bTime = bDate.timeIntervalSince1970
            if aTime < bTime {
                setZoom(min: min(aTime, bTime), max: max(aTime, bTime))
            }
        }
        
        mouseDownEvent = nil
        mouseDraggedEvent = nil
        
        needsDisplay = true
    }
    
    open func pan(by amount: TimeInterval) {
        //        NSLog("pan \(amount)")
        let minTime = amount - timeOffset
        let w = Double(bounds.size.width)
        let timeInterval = w / timeScale
        let maxTime = minTime + timeInterval
        setZoom(min: minTime, max: maxTime)
    }
    
    open func zoom(at x: CGFloat, on date: Date, by amount: Double) {
        //        NSLog("zoom \(date) \(amount)")
        let newTimeScale = timeScale * amount
        let w = Double(bounds.size.width)
        let timeInterval = w / newTimeScale
        let f = Double(x) / w
        let minTime = date.timeIntervalSince1970 - f * timeInterval
        let maxTime = minTime + timeInterval
        setZoom(min: minTime, max: maxTime)
    }
    
    override open func scrollWheel(with event: NSEvent) {
        let dx = Double(event.scrollingDeltaX)
        let dy = Double(event.scrollingDeltaY)
        if abs(dx) >= abs(dy) {
            let amount = -dx * 0.1 / timeScale
            pan(by: amount)
        } else {
            let point = convert(event.locationInWindow, from: nil)
            let (date, _) = eventToSample(event: event)
            let amount: Double = 1.0 - dy * 0.1
            zoom(at: point.x, on: date, by: amount)
        }
    }
    
    open func zoomAll() {
        zoomRange = nil
        
        needsDisplay = true
    }
    
    open func addPoint(path: NSBezierPath, x: Double, y: Double, move: Bool) {
        if (path.elementCount) == 0 || move {
            path.move(to: NSPoint(x: x, y: y))
        } else {
            path.line(to: NSPoint(x: x, y: y))
        }
    }
    
    open func samplesCovering(samples: [Sample], range: (min: Double, max: Double)) -> [Sample] {
        var result = [Sample]()
        for (index, sample) in samples.enumerated() {
            if result.isEmpty {
                if range.min <= sample.date.timeIntervalSince1970 {
                    if index > 0 {
                        result.append(samples[index - 1])
                    }
                    result.append(sample)
                }
            } else {
                if sample.date.timeIntervalSince1970 <= range.max {
                    result.append(sample)
                } else {
                    result.append(sample)
                    break
                }
            }
        }
        return result
    }
    
    override open func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.black.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height))
        
        let font = NSFont.systemFont(ofSize: 10)
        let attributes = [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: NSColor.white]
        
        var samples = self.samples
        guard let firstSample = samples.first else {
            return
        }
        var firstTime = firstSample.date.timeIntervalSince1970
        var lastTime = samples.last!.date.timeIntervalSince1970
        if (lastTime - firstTime) < 0.010 {
            return
        }
        if let zoomRange = self.zoomRange {
            (firstTime, lastTime) = zoomRange
            samples = samplesCovering(samples: samples, range: zoomRange)
        }
        
        timeOffset = -firstTime
        timeScale = Double(bounds.size.width) / (lastTime - firstTime)
        
        currentOffset = 0.0
        currentScale = Double(bounds.size.height) / (currentMax - 0.0)
        
        let currentPath = NSBezierPath()
        var previousTime = firstTime
        for sample in samples {
            let time = sample.date.timeIntervalSince1970
            let x = (time + timeOffset) * timeScale
            
            let move = (time - previousTime) > discontinuity
            addPoint(path: currentPath, x: x, y: (sample.current + currentOffset) * currentScale, move: move)
            
            previousTime = time
        }
        NSColor.yellow.setStroke()
        currentPath.stroke()
        
        let y = bounds.size.height - 12.0
        tip.draw(at: NSPoint(x: 0, y: y), withAttributes: attributes)
        let x = bounds.size.width - summary.size(withAttributes: attributes).width
        summary.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
        
        if let down = mouseDownEvent {
            let p = convert(down.locationInWindow, from: nil)
            NSColor.blue.setStroke()
            let t = bounds.origin.y + bounds.size.height
            NSBezierPath.strokeLine(from: NSPoint(x: p.x, y: 0), to: NSPoint(x: p.x, y: t))
            let r = bounds.origin.x + bounds.size.width
            NSBezierPath.strokeLine(from: NSPoint(x: 0, y: p.y), to: NSPoint(x: r, y: p.y))
        }
        if let dragged = mouseDraggedEvent {
            let p = convert(dragged.locationInWindow, from: nil)
            NSColor.blue.setStroke()
            let t = bounds.origin.y + bounds.size.height
            NSBezierPath.strokeLine(from: NSPoint(x: p.x, y: 0), to: NSPoint(x: p.x, y: t))
            let r = bounds.origin.x + bounds.size.width
            NSBezierPath.strokeLine(from: NSPoint(x: 0, y: p.y), to: NSPoint(x: r, y: p.y))
        }
    }
    
}
