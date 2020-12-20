//
//  RecordViewController.swift
//  HackUMass2020
//
//  Created by Maxwell Hubbard on 12/17/20.
//

import Foundation
import UIKit
import MapboxVision
import MapboxVisionSafety
import MapboxVisionAR
import MapboxVisionARNative

class RecordViewController: UIViewController {
    
    private var visionManager: VisionManager!
    private var visionSafetyManager: VisionSafetyManager!
    private var visionARManager: VisionARManager!
    var videoSource: CameraVideoSource!
    
    private let visionViewController = VisionARViewController()
    
    @IBOutlet weak var backView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addARView()
        
        videoSource = CameraVideoSource()
        visionManager = VisionManager.create(videoSource: videoSource)

        // setup AR and/or Safety if needed
        visionARManager = VisionARManager.create(visionManager: visionManager)

        visionSafetyManager = VisionSafetyManager.create(visionManager: visionManager)
        
        visionViewController.set(arManager: visionARManager)
        

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
     
        visionManager.start()
        videoSource.start()
    }
     
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
     
        videoSource.stop()
        visionManager.stop()
    }
     
    private func addARView() {
        addChild(visionViewController)
        backView.addSubview(visionViewController.view)
        visionViewController.didMove(toParent: self)
    }
    
    deinit {
        // free up VisionSafetyManager's resources
        visionSafetyManager.destroy()
        
        visionARManager.destroy()
        
        // free up VisionManager's resources
        visionManager.destroy()
    }
    
    
    @IBAction func startRecording(_ sender: Any) {
        print("Starting recording")
        // will throw an exception if `visionManager` hasn't been started beforehand
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_HH_mm"
        let date = formatter.string(from: Date())
        
        let DocumentDirectory = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        let DirPath = DocumentDirectory.appendingPathComponent(date)
        do
        {
            try FileManager.default.createDirectory(atPath: DirPath!.path, withIntermediateDirectories: true, attributes: nil)
            
            FileManager.default.createFile(atPath: DirPath!.path + "/gps.bin", contents: nil, attributes: nil)
            try? visionManager.startRecording(to: DirPath!.path)
        }
        catch let error as NSError
        {
            print("Unable to create directory \(error.debugDescription)")
        }
        
    }
    
    @IBAction func stopRecording(_ sender: Any) {
        print("Stopping recording")
        // when you're ready to finish recording
        visionManager.stopRecording()
    }
    
}
