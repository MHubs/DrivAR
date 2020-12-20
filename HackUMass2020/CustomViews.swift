//
//  CustomViews.swift
//  HackUMass2020
//
//  Created by Maxwell Hubbard on 12/20/20.
//

import Foundation
import UIKit

// Custom UIView to draw a red alert with a gradient background on a specific part of the app
class CollisionDetectionView: UIView {
    
    private var alertOverspeedingView: UIView!
    private let gradientLayer = RadialGradientLayer()
    var startTime: TimeInterval!
    
    var colors: [UIColor] {
        get {
            return gradientLayer.colors
        }
        set {
            gradientLayer.colors = newValue
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        startTime = Date().timeIntervalSince1970
        // Transparent view with a red border
        backgroundColor = .clear
        colors = [UIColor(displayP3Red: 200.0/255.0, green: 0, blue: 0, alpha: 0.75), .clear]
        
        alertOverspeedingView = UIImageView(image: UIImage(named: "alert"))
        alertOverspeedingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(alertOverspeedingView)
        NSLayoutConstraint.activate([
            alertOverspeedingView.centerYAnchor.constraint(equalTo: centerYAnchor),
            alertOverspeedingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            alertOverspeedingView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.33),
            alertOverspeedingView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.33)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if gradientLayer.superlayer == nil {
            layer.insertSublayer(gradientLayer, at: 0)
        }
        gradientLayer.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


// Class to handle how point of interest icons look
class PointOfInterestView: UIView {
    
    var imageView: UIImageView!
    var text: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView = UIImageView()
        text = UILabel()
        
        text.numberOfLines = 0
        text.lineBreakMode = .byWordWrapping
        text.textAlignment = .center
        text.font = UIFont.systemFont(ofSize: 5)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.7)
        ])
        
        text.translatesAutoresizingMaskIntoConstraints = false
        addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: topAnchor),
            text.centerXAnchor.constraint(equalTo: centerXAnchor),
            text.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1),
            text.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.3)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

// Custom class needed for passing along parameters in Selector

class FileTapGesture: UITapGestureRecognizer {
    var item: String!
}
