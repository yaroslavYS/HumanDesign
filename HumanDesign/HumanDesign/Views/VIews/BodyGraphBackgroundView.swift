//
//  BodyGraphBackgroundView.swift
//  HumanDesign
//
//  Created by Dmytro Pasinchuk on 12/21/18.
//  Copyright © 2018 Pavlo Kharambura. All rights reserved.
//

import UIKit

class BodyGraphBackgroundView: UIView {
    
//    @IBOutlet var contentView: UIView!
    
    var numberViews: [BodyGraphNumberView] = []
    var connectedByLinesGraphNumbers: [Int:Int] = [:]

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let context = UIGraphicsGetCurrentContext()
        context?.clear(rect)
        guard !numberViews.isEmpty, !connectedByLinesGraphNumbers.isEmpty else { return }
        drawGraphLines()
    }
    
    func drawGraphLines() {
        for lineIndexes in connectedByLinesGraphNumbers {
            guard let startOfLine = numberViews.first (where: { (numberView) -> Bool in
                numberView.labelsNumber == lineIndexes.key
            }) else { return }
            guard let endOfLine = numberViews.first (where: { (numberView) -> Bool in
                numberView.labelsNumber == lineIndexes.value
            }) else { return }
            drawLine(from: startOfLine, to: endOfLine)
        }
    }
    
    private func drawLine(from firstNumberView: BodyGraphNumberView, to secondNumberView: BodyGraphNumberView) {
        let startCoordinate = firstNumberView.center
        let endCoordinate = secondNumberView.center
        
        let middleXCoordinate = (abs(firstNumberView.center.x - secondNumberView.center.x)/2)
        let middleYCoordinate = (abs(firstNumberView.center.y - secondNumberView.center.y)/2)
        let middleOfLine = CGPoint(x: middleXCoordinate, y: middleYCoordinate)
        
        if !firstNumberView.numberIsActive && !secondNumberView.numberIsActive {
            drawLine(from: startCoordinate, to: endCoordinate, with: .white)
        } else {
            if firstNumberView.numberIsActive && secondNumberView.numberIsActive {
                drawLine(from: startCoordinate, to: endCoordinate, with: .greyPurple)
            } else {
                //TODO: draw right color of parts
                if firstNumberView.numberIsActive {
                    drawLine(from: startCoordinate, to: middleOfLine, with: .red)
                    drawLine(from: middleOfLine, to: endCoordinate, with: .white)
                } else {
                    drawLine(from: startCoordinate, to: middleOfLine, with: .white)
                    drawLine(from: middleOfLine, to: endCoordinate, with: .blue)
                }
            }
        }
    }
    
    private func drawLine(from firstPoint: CGPoint, to secondPoint: CGPoint, with color: UIColor) {
        let linePath = UIBezierPath()
        linePath.lineWidth = 4.0
        color.setStroke()
        linePath.move(to: firstPoint)
        linePath.addLine(to: secondPoint)
        linePath.stroke()
    }

}
