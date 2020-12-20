import MapboxVision
import MapboxVisionSafety
import MapboxVisionARNative
import MapboxVisionAR
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
import UIKit
import AVFoundation
import MediaPlayer
import Speech
import Contacts
import CoreLocation
import MapKit
import RadarSDK

/**
 * "Safety alerts" example demonstrates how to utilize events from MapboxVisionSafetyManager
 * to alert a user about exceeding allowed speed limit and potential collisions with other cars.
 */

// Custom UIView to draw a red bounding box
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

extension String {
    func localized(_ lang:String) ->String {

        let path = Bundle.main.path(forResource: lang, ofType: "lproj")
        let bundle = Bundle(path: path!)

        return NSLocalizedString(self, tableName: nil, bundle: bundle!, value: "", comment: "")
    }
}

class ARNavigationViewController: UIViewController, AVSpeechSynthesizerDelegate, SFSpeechRecognizerDelegate {
    private var visionManager: VisionReplayManager!
    var visionAManager: VisionManager!
    private var visionSafetyManager: VisionSafetyManager!
    
    private let visionViewController = VisionPresentationViewController()
    
    var videoSource: CameraVideoSource!
    var visionARManager: VisionARManager!
    
    var locManager = CLLocationManager()
    var currentLocation: CLLocation!
    var destination: CLLocation!
    
    let visionARViewController = VisionARViewController()
    
    private var alertOverspeedingView: UIView!
    
    private var vehicleState: VehicleState?
    private var speedLimit: Float?
    private var carCollisions = [CollisionObject]()
    
    private var liveDemo: Bool = false
    
    private var acceleration: Float!
    private var timeSinceUpdate: TimeInterval!
    
    @IBOutlet weak var backView: UIView!
    @IBOutlet weak var fileView: UIView!
    @IBOutlet weak var speedLimitView: UIView!
    @IBOutlet weak var speedLimitNumber: UILabel!
    
    @IBOutlet weak var yourSpeedView: UIVisualEffectView!
    @IBOutlet weak var yourSpeedNumber: UILabel!
    
    @IBOutlet weak var slowDownView: UIVisualEffectView!
    
    @IBOutlet weak var slowDownText: UILabel!
    
    @IBOutlet weak var directionView: UIVisualEffectView!
    @IBOutlet weak var directionLabel: UILabel!
    
    
    var previousAlert: TimeInterval = 0
    var previousPOICheck: TimeInterval = 0
    
    var changeBackSound = false
    let volumeView = MPVolumeView()
    let synthesizer = AVSpeechSynthesizer()
    
    private let audioEngine = AVAudioEngine()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var wakeRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var wakeRecognitionTask: SFSpeechRecognitionTask?
    
    var recording: Bool = false
    var calibrated: Bool = false
    
    @IBOutlet weak var speechButton: UIImageView!
    @IBOutlet weak var destinationView: UIVisualEffectView!
    @IBOutlet weak var destinationLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    
    
    var pointOfInterestCategories: [String] = ["arts-entertainment", "transit-system", "education", "government-building", "major-us-airport","major-us-sports-venue-stadium", "hotel-lodging", "medical-health", "public-services-government", "religion", "science-engineering", "shopping-retail", "sports-recreation", "travel-transportation", "gas-station"]
    var pointsOfInterest: [GeoCoordinate:(UIImage, RadarPlace?)] = [:]
    var camera: Camera?
    
    
    @IBOutlet weak var hamburgerButton: UIButton!
    @IBOutlet weak var settingsView: UIVisualEffectView!
    
    @IBOutlet weak var unitSlider: UISlider!
    
    var units: Units = Units.BOTH
    
    let languages: [String] = ["en-US", "fr-FR", "es-ES"]
    var currentLanguage: String = "en-US"
    var languageConvert: [String:String] = ["en-US" : "en", "fr-FR" : "fr", "es-ES" : "es"]
    
    @IBOutlet weak var yourSpeedLabel: UILabel!
    @IBOutlet weak var speedLimitLabel: UILabel!
    @IBOutlet weak var unitsLabel: UILabel!
    @IBOutlet weak var metricLabel: UILabel!
    @IBOutlet weak var imperialLabel: UILabel!
    @IBOutlet weak var languageLabel: UILabel!
    @IBOutlet weak var languagePicker: UIPickerView!
    
    
    
    
    @IBAction func onHamburgerTap(_ sender: UIButton) {
        
        if mpsToMPH(speed: vehicleState!.speed) == 0 || liveDemo == false {
            
            if self.settingsView.alpha == 0 {
                UIView.animate(withDuration: 1, animations: {
                    self.settingsView.alpha = 1
                })
            } else {
                UIView.animate(withDuration: 1, animations: {
                    self.settingsView.alpha = 0
                })
            }
            
        }
        
    }
    
    @IBAction func onUnitSliderChange(_ sender: UISlider) {
        let stepSize: Float = 1.0
        unitSlider.setValue(stepSize * floorf((unitSlider.value / stepSize) + 0.5), animated: false)
                
        if unitSlider.value == 0 {
            units = Units.METRIC
        } else if unitSlider.value == 2 {
            units = Units.IMPERIAL
        } else {
            units = Units.BOTH
        }
        
    }
    
    enum Units {
        case METRIC
        case IMPERIAL
        case BOTH
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hamburgerButton.alpha = 0
        
        settingsView.layer.cornerRadius = 5
        settingsView.clipsToBounds = true
        
        speedLimitView.backgroundColor = .white
        speedLimitNumber.textColor = .black
        speedLimitView.layer.cornerRadius = 5
        
        yourSpeedView.layer.cornerRadius = 5
        yourSpeedView.clipsToBounds = true
        
        directionView.layer.cornerRadius = 5
        directionView.clipsToBounds = true
        
        let wrappingView = UIView(frame: CGRect(x: 3, y: 3, width: speedLimitView.frame.width - 6, height: speedLimitView.frame.height - 6))
        wrappingView.backgroundColor = .clear
        wrappingView.layer.borderColor = UIColor.black.cgColor
        wrappingView.layer.borderWidth = 2.0;
        wrappingView.layer.cornerRadius = 5
        speedLimitView.addSubview(wrappingView)
        
        speedLimitView.alpha = 0
        yourSpeedView.alpha = 0
        directionView.alpha = 0
        settingsView.alpha = 0
        
        slowDownView.alpha = 0
        
        synthesizer.delegate = self
        
        recordButton.isEnabled = false
        recordButton.alpha = 0
        
        speechButton.alpha = 0
        destinationView.alpha = 0
        
        hamburgerButton.layer.cornerRadius = hamburgerButton.frame.width / 2
        
        
        languagePicker.delegate = self
        languagePicker.dataSource = self
        
        
        
        // Documents directory path with files uploaded via Finder
        let documentsPath =
            NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                .userDomainMask,
                                                true).first!
        
        fileView.alpha = 1
        
        
        do {
            let fileURLS = try FileManager.default.contentsOfDirectory(atPath: documentsPath)
            
            var i: CGFloat = 0.0
            for url in fileURLS {
                
                let label = UILabel(frame: CGRect(x: CGFloat(0), y: i, width: fileView.frame.width, height: fileView.frame.height / CGFloat(fileURLS.count + 1)))
                label.text = url
                label.isUserInteractionEnabled = true
                let ges = FileTapGesture(target: self, action: #selector(setUp(_:)))
                ges.item = url
                label.addGestureRecognizer(ges)
                i += fileView.frame.height / CGFloat(fileURLS.count + 1)
                
                fileView.addSubview(label)
            }
            
            let label = UILabel(frame: CGRect(x: CGFloat(0), y: i, width: fileView.frame.width, height: fileView.frame.height / CGFloat(fileURLS.count + 1)))
            label.text = "Live Test"
            label.isUserInteractionEnabled = true
            let ges = FileTapGesture(target: self, action: #selector(setUpAR(_:)))
            ges.item = "Live Test"
            label.addGestureRecognizer(ges)
            i += fileView.frame.height / CGFloat(fileURLS.count + 1)
            
            fileView.addSubview(label)
            
        } catch {
            
        }
    }
    
    class FileTapGesture: UITapGestureRecognizer {
        var item: String!
    }
    
    @objc func setUp(_ sender: FileTapGesture) {
        
        print("Tapped on " + sender.item)
        
        fileView.alpha = 0
        liveDemo = false
        hamburgerButton.alpha = 1
        
        let documentsPath =
            NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                .userDomainMask,
                                                true).first!
        
        let path = documentsPath.appending("/" + sender.item)
        
        // create VisionReplayManager with a path to recorded session
        visionManager = try? VisionReplayManager.create(recordPath: path)
        // register its delegate
        visionManager.delegate = self
        
        // create VisionSafetyManager and register as its delegate to receive safety related events
        visionSafetyManager = VisionSafetyManager.create(visionManager: visionManager)
        visionSafetyManager.setTimeToCollisionWithVehicle(warningTime: 25, criticalTime: 3)
        // register its delegate
        visionSafetyManager.delegate = self
        
        // configure Vision view to display sample buffers from video source
        visionViewController.set(visionManager: visionManager)
        // add Vision view as a child view
        addVisionView()
        
        visionManager.start()
        
        
        
    }
    
    @objc func setUpAR(_ sender: FileTapGesture) {
        
        print("Tapped on " + sender.item)
        
        fileView.alpha = 0
        
        liveDemo = true
        hamburgerButton.alpha = 1
        
        addARView()
        
        // create a video source obtaining buffers from camera module
        videoSource = CameraVideoSource()
        
        // create VisionManager with video source
        visionAManager = VisionManager.create(videoSource: videoSource)
        // create VisionARManager
        visionARManager = VisionARManager.create(visionManager: visionAManager)
        // configure AR view to display AR navigation
        visionARViewController.set(arManager: visionARManager)
        
        visionAManager.delegate = self
        
        
        // create VisionSafetyManager and register as its delegate to receive safety related events
        visionSafetyManager = VisionSafetyManager.create(visionManager: visionAManager)
        visionSafetyManager.setTimeToCollisionWithVehicle(warningTime: 25, criticalTime: 3)
        // register its delegate
        visionSafetyManager.delegate = self
        
        //GPS Location use
        locManager.requestAlwaysAuthorization()
        locManager.requestWhenInUseAuthorization()
        
        destinationView.alpha = 0
        destinationView.layer.cornerRadius = destinationView.frame.width / 8
        destinationView.clipsToBounds = true
        
        recordButton.isEnabled = false
        recordButton.alpha = 0
        
        speechButton.alpha = 1
        
        if CLLocationManager.locationServicesEnabled() {
            currentLocation = locManager.location
        }
        
        
        // Speech recognition
        speechRecognizer.delegate = self
        
        // Make the authorization request
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            // Asynchronously make the authorization request.
            SFSpeechRecognizer.requestAuthorization { authStatus in
                
                // Divert to the app's main thread so that the UI
                // can be updated.
                OperationQueue.main.addOperation {
                    switch authStatus {
                    case .authorized: break
                        
                        
                    case .denied: break
                        
                        
                    case .restricted: break
                        
                        
                    case .notDetermined: break
                        
                        
                    default: break
                    }
                }
            }
        }
        
        speechButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onMicrophoneTap)))
        
        
        let laneVisualParams = LaneVisualParams()
        
        visionARViewController.set(laneVisualParams: laneVisualParams)
        visionARViewController.isFenceVisible = true
        
        visionAManager.start()
        videoSource.start()
        
        
    }
    
    private func addARView() {
        addChild(visionARViewController)
        backView.addSubview(visionARViewController.view)
        visionARViewController.didMove(toParent: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
    }
    

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        visionManager.stop()
        visionAManager.stop()
    }
    
    deinit {
        // free up VisionSafetyManager's resources
        visionSafetyManager.destroy()
        
        visionARManager.destroy()
        
        // free up VisionManager's resources
        visionManager.destroy()
    }
    
    @objc func onMicrophoneTap() {
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            
        } else {
            speak(text: "Where".localized(languageConvert[currentLanguage]!))
        }
        
    }
    
    private func addVisionView() {
        addChild(visionViewController)
        backView.addSubview(visionViewController.view)
        visionViewController.didMove(toParent: self)
    }
    
    // MARK: - Handle VisionSafety events
    
    private func updateCollisionDrawing() {
        // remove `CollisionDetectionView` objects from the view
        for subview in view.subviews {
            if subview.isKind(of: CollisionDetectionView.self) {
                subview.removeFromSuperview()
                
            }
        }
        if carCollisions.first(where: { $0.dangerLevel == .critical }) != nil {
            slowDownText.text = "Slow".localized(languageConvert[currentLanguage]!)
            slowDownView.alpha = 1
            
        } else {
            slowDownView.alpha = 0
        }
        
        // iterate the collection of `CollisionObject`s and draw each of them
        for carCollision in carCollisions {
            
            let relativeBBox = carCollision.lastDetection.boundingBox
            let cameraFrameSize = carCollision.lastFrame.image.size.cgSize
            
            // calculate absolute coordinates
            let bboxInCameraFrameSpace = CGRect(x: relativeBBox.origin.x * cameraFrameSize.width,
                                                y: relativeBBox.origin.y * cameraFrameSize.height,
                                                width: relativeBBox.size.width * cameraFrameSize.width,
                                                height: relativeBBox.size.height * cameraFrameSize.height)
            
            // at this stage, bbox has the coordinates in the camera frame space
            // you should convert it to the view space saving the aspect ratio
            
            // first, construct left-top and right-bottom coordinates of a bounding box
            var leftTop = CGPoint(x: bboxInCameraFrameSpace.origin.x,
                                  y: bboxInCameraFrameSpace.origin.y)
            var rightBottom = CGPoint(x: bboxInCameraFrameSpace.maxX,
                                      y: bboxInCameraFrameSpace.maxY)
            
            // then convert the points from the camera frame space into the view frame space
            leftTop = leftTop.convertForAspectRatioFill(from: cameraFrameSize,
                                                        to: view.bounds.size)
            rightBottom = rightBottom.convertForAspectRatioFill(from: cameraFrameSize,
                                                                to: view.bounds.size)
            
            // finally, construct a bounding box in the view frame space
            let bboxInViewSpace = CGRect(x: leftTop.x,
                                         y: leftTop.y,
                                         width: rightBottom.x - leftTop.x,
                                         height: rightBottom.y - leftTop.y)
            
            // draw a collision detection alert
            let view = CollisionDetectionView(frame: bboxInViewSpace)
            self.view.addSubview(view)
        }
    }
    
    private func updateSpeed() {
        // when update is completed all the data has the most current state
        guard let vehicle = vehicleState else {return}
        
        if speedLimit == nil {
            return
        }
        
        if units == Units.METRIC {
            yourSpeedNumber.text = String(Int(mpsToKPH(speed: vehicle.speed)))
            speedLimitNumber.text = String(Int(mphToKPH(speed: Int(speedLimit!))))
        } else {
            yourSpeedNumber.text = String(mpsToMPH(speed: vehicle.speed))
            speedLimitNumber.text = String(Int(speedLimit!))
        }
        
        
        if vehicle.speed > mphToMPS(speed: Int(speedLimit!)) && speedLimit! > 0 {
            yourSpeedView.contentView.backgroundColor = UIColor(displayP3Red: CGFloat((50.0 / 255.0) * vehicle.speed / mphToMPS(speed: Int(speedLimit!))), green: 0, blue: 0, alpha: 0.5)
            
            if mpsToMPH(speed: vehicle.speed) >= Int(speedLimit!) + 15 {
                if (previousAlert == 0 || Date().timeIntervalSince1970 - previousAlert > 4) {
                    speak(text: "Slow".localized(languageConvert[currentLanguage]!))
                    previousAlert = Date().timeIntervalSince1970
                }
                
            }
            
            
        } else {
            yourSpeedView.contentView.backgroundColor = .clear
        }
        
        if mpsToMPH(speed: vehicle.speed) == 0 && destinationView.alpha <= 0.11 && destinationView.alpha > 0 {
            UIView.animate(withDuration: 2, delay: 0, options: UIView.AnimationOptions.allowAnimatedContent, animations: {
                
                self.destinationView.alpha = 1
                
            }, completion: nil)
        } else if mpsToMPH(speed: vehicle.speed) != 0 && destinationView.alpha == 1 {
            UIView.animate(withDuration: 2, delay: 0, options: UIView.AnimationOptions.allowAnimatedContent, animations: {
                
                self.destinationView.alpha = 0.1
                
            }, completion: nil)
        }
        
        if (mpsToMPH(speed: vehicle.speed) == 0 && hamburgerButton.alpha == 0) || liveDemo == false {
            UIView.animate(withDuration: 2, delay: 0, options: UIView.AnimationOptions.allowAnimatedContent, animations: {
                self.hamburgerButton.isEnabled = true
                self.hamburgerButton.alpha = 1
                
            }, completion: nil)
        } else if mpsToMPH(speed: vehicle.speed) != 0 && hamburgerButton.alpha == 1 && liveDemo {
            UIView.animate(withDuration: 2, delay: 0, options: UIView.AnimationOptions.allowAnimatedContent, animations: {
                
                self.hamburgerButton.isEnabled = false
                self.hamburgerButton.alpha = 0
                
                self.settingsView.alpha = 0
                
            }, completion: nil)
        }
        
    }
    
    private func updateSpeedLimitView(maxSpeed: Float) {
        // when update is completed all the data has the most current state
        guard let vehicle = vehicleState else {return}
        
        if maxSpeed > 0 {
            
            if units == Units.METRIC {
                speedLimitNumber.text = String(Int(mphToKPH(speed: Int(maxSpeed))))
            } else {
                speedLimitNumber.text = String(Int(maxSpeed))
            }
            
            speedLimitView.alpha = 1
            yourSpeedView.alpha = 1
        }
        
        if units == Units.METRIC {
            yourSpeedNumber.text = String(Int(mpsToKPH(speed: vehicle.speed)))
        } else {
            yourSpeedNumber.text = String(mpsToMPH(speed: vehicle.speed))
        }
        
        if vehicle.speed > mphToMPS(speed: Int(maxSpeed)) && maxSpeed > 0 {
            
            yourSpeedView.contentView.backgroundColor = UIColor(displayP3Red: CGFloat((50.0 / 255.0) * vehicle.speed / mphToMPS(speed: Int(maxSpeed))), green: 0, blue: 0, alpha: 0.5)
            
            if mpsToMPH(speed: vehicle.speed) >= Int(maxSpeed) + 15 {
                if (previousAlert == 0 || Date().timeIntervalSince1970 - previousAlert > 4) {
                    speak(text: "Slow".localized(languageConvert[currentLanguage]!))
                    previousAlert = Date().timeIntervalSince1970
                }
                
            }
            
            
        } else {
            yourSpeedView.contentView.backgroundColor = .clear
        }
        
    }
    
    func mpsToMPH(speed: Float) -> Int {
        return Int(speed * 2.237)
    }
    
    func mpsToKPH(speed: Float) -> Int {
        return Int(speed * 3.6)
    }
    
    func mphToMPS(speed: Int) -> Float {
        return Float(speed) / 2.237
    }
    
    func mphToKPH(speed: Int) -> Float {
        return Float(speed) * 1.609
    }
    
    func distToCrash(speed: Float, time: Float) -> Float {
        return 0 + speed * time + 0.5 * acceleration * time * time
    }
    
    func metersToFeet(meters: Float) ->Float {
        return meters * 3.281
    }
    
    func setVolume(_ volume: Float) {
        
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05) {
            slider?.value = volume
        }
    }
    
    func getVolume() -> Float {
        // Search for the slider
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        // Update the slider value with the desired volume.
        
        return slider!.value
        
    }
    
    func speak(text: String) {
        
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch(let error) {
            print(error.localizedDescription)
        }
        
        if getVolume() == 0 {
            changeBackSound = true
            setVolume(0.3)
        }
                
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: currentLanguage)
        
        
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }
        
        
        synthesizer.speak(utterance)
        
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if changeBackSound {
            changeBackSound = false
            setVolume(0)
        }
        
        if utterance.speechString == "Where".localized(languageConvert[currentLanguage]!) {
            do {
                try startSpeechRecognition()
            }  catch {
                
            }
        }
    }
    
    
    
    func getNearbyPOIs() {
        
        if vehicleState == nil {
            return
        }
        
        let location = CLLocation(latitude: vehicleState!.location.coordinate.lat, longitude: vehicleState!.location.coordinate.lon)
        
        Radar.searchPlaces(near: location, radius: 1000, chains:nil, categories: pointOfInterestCategories, groups: nil, limit: 90){
            (status, loc, places) in
            
            if status == RadarStatus.success {
                
                if places!.count > 0 {
                    
                    self.pointsOfInterest.removeAll()
                    
                    for place in places! {
                        
                        var cat = ""
                        
                        for cats in place.categories {
                            if self.pointOfInterestCategories.contains(cats) {
                                cat = cats
                                break
                            }
                        }
                        
                        let image = UIImage(named: cat)!
                        let coord = GeoCoordinate(lon: place.location.coordinate.longitude, lat: place.location.coordinate.latitude)
                        self.pointsOfInterest[coord] = (image, place)
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    private let distanceVisibilityThreshold = 500.0
    private let distanceAboveGround = 16.0
    private let poiDimension = 12.0
    
    func updatePOIs() {
        
        for subview in view.subviews {
            if subview.isKind(of: PointOfInterestView.self) {
                subview.removeFromSuperview()
                
            }
        }
        
        if (destination != nil) && addressLabel.text != "Address" {
            pointsOfInterest[GeoCoordinate(lon: destination.coordinate.longitude, lat: destination.coordinate.latitude)] = (UIImage(named: "destination")!, nil)
        }
        
        
        
        
        for (coord, (image, place)) in pointsOfInterest {
            
            
            guard
                // make sure that `Camera` is calibrated for more precise transformations
                let camera = camera, camera.isCalibrated,
                // convert geo to world
                let poiWorldCoordinate = liveDemo ? visionAManager.geoToWorld(geoCoordinate: coord) : visionManager.geoToWorld(geoCoordinate: coord),
                // make sure POI is in front of the camera and not too far away
                poiWorldCoordinate.x > 0, poiWorldCoordinate.x < distanceVisibilityThreshold
            else {
                //print("Camera is null / not calibrated", self.camera)
                return
            }
            
            // by default the translated geo coordinate is placed at 0 height in the world space.
            // If you'd like to lift it above the ground alter its `z` coordinate
            let worldCoordinateLeftTop =
                WorldCoordinate(x: poiWorldCoordinate.x,
                                y: poiWorldCoordinate.y - poiDimension / 2,
                                z: distanceAboveGround + poiDimension / 2)
            
            let worldCoordinateRightBottom =
                WorldCoordinate(x: poiWorldCoordinate.x,
                                y: poiWorldCoordinate.y + poiDimension / 2,
                                z: distanceAboveGround - poiDimension / 2)
            
            
            guard
                // convert the POI to the screen coordinates
                let screenCoordinateLeftTop = liveDemo ? visionAManager.worldToPixel(worldCoordinate: worldCoordinateLeftTop) :
                    visionManager.worldToPixel(worldCoordinate: worldCoordinateLeftTop),
                
                let screenCoordinateRightBottom = liveDemo ? visionAManager.worldToPixel(worldCoordinate: worldCoordinateRightBottom) :
                    visionManager.worldToPixel(worldCoordinate: worldCoordinateRightBottom)
            else {
                return
            }
            
            // translate points from the camera frame space to the view space
            let frameSize = camera.frameSize.cgSize
            let viewSize = view.bounds.size
            
            let leftTop = screenCoordinateLeftTop.cgPoint
                .convertForAspectRatioFill(from: frameSize, to: viewSize)
            
            let rightBottom = screenCoordinateRightBottom.cgPoint
                .convertForAspectRatioFill(from: frameSize, to: viewSize)
            
            // construct and apply POI view frame rectangle
            let poiFrame = CGRect(x: leftTop.x,
                                  y: leftTop.y,
                                  width: rightBottom.x - leftTop.x,
                                  height: rightBottom.y - leftTop.y)
            
            
            let poiView = PointOfInterestView()
            poiView.imageView.image = image
            if place != nil {
                poiView.text.text = place!.name
            } else {
                poiView.text.text = destinationLabel.text
            }
            
            
            poiView.frame = poiFrame
            view.addSubview(poiView)
            
        }
        
        
        
        
    }
    
    
    /*
     
     AR View
     
     */
    
    var detectionTimer: Timer?
    
    
    
    
    func startSpeechRecognition() throws  {
        
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 1, animations: {
                self.speechButton.transform = CGAffineTransform(scaleX: 2, y: 2)
            }) { (finished) in
                
            }
            
            
        }
        
        
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Update the text view with the results.
                isFinal = result.isFinal
                print("Text \(result.bestTranscription.formattedString)", result.isFinal)
                
                if self.detectionTimer != nil {
                    self.detectionTimer!.invalidate()
                }
            }
            
            if let timer = self.detectionTimer, timer.isValid {
                if isFinal {
                    self.detectionTimer?.invalidate()
                }
            } else {
                self.detectionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { (timer) in
                    isFinal = true
                    timer.invalidate()
                    
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    
                    if isFinal {
                        
                        DispatchQueue.main.async {
                            
                            UIView.animate(withDuration: 1, animations: {
                                self.speechButton.transform = CGAffineTransform.identity
                            })
                        }
                        
                        self.performSearch(searchText: (result?.bestTranscription.formattedString)!)
                        
                    }
                    
                })
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                if self.detectionTimer != nil {
                    self.detectionTimer!.invalidate()
                }
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                
                if isFinal {
                    
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 1, animations: {
                            self.speechButton.transform = CGAffineTransform.identity
                        })
                    }
                    
                    
                    
                    self.performSearch(searchText: (result?.bestTranscription.formattedString)!)
                    
                }
                
            }
        }
        
        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    
    func performSearch(searchText: String) {
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        currentLocation = locManager.location
        
        getStreet(from: currentLocation, completion: {
            placemarks, error in
            
            guard let placeMark = placemarks?.first else { return }
            
            
            // Full Address
            if let postalAddress = placeMark.postalAddress {
                let streets = postalAddress.street.split(separator: "–", maxSplits: 1, omittingEmptySubsequences: false)
                
                var addr = ""
                if streets.count > 1{
                    let removedHyphen = streets[1].split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                    addr = streets[0] + " " + removedHyphen[1] + ", " + postalAddress.city + ", " + postalAddress.state
                } else {
                    addr = streets[0] + ", " + postalAddress.city + ", " + postalAddress.state
                }
                print("Current: " + addr, placeMark)
                
            }
            
        })
        
        let region = MKCoordinateRegion(center: currentLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        
        request.region = region
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let response = response else {
                
                self.displayDestination(mapItem: nil)
                
                return
            }
            
            let item = response.mapItems[0]
            print(item)
            
            self.destination = item.placemark.location
            
            self.displayDestination(mapItem: item)
            
            self.startRouting()
            
            
        }
        
    }
    
    func displayDestination(mapItem: MKMapItem?) {
        
        if mapItem == nil {
            destinationLabel.text = "Try".localized(languageConvert[currentLanguage]!)
            addressLabel.text = "Understand".localized(languageConvert[currentLanguage]!)
        } else {
            destinationLabel.text = mapItem!.name
            addressLabel.text = getFormattedAddress(pm: mapItem!.placemark)
        }
        
        
        
        UIView.animate(withDuration: 2, animations: {
            
            self.destinationView.alpha = 1
            
        }, completion: { done in
            
            if self.destinationLabel.text == "Try".localized(self.languageConvert[self.currentLanguage]!) {
                UIView.animate(withDuration: 2, delay: 5, options: UIView.AnimationOptions.allowAnimatedContent, animations: {
                    
                    self.destinationView.alpha = 0
                    
                }, completion: nil)
            } else {
                UIView.animate(withDuration: 2, delay: 5, options: UIView.AnimationOptions.allowAnimatedContent, animations: {
                    
                    self.destinationView.alpha = 0.1
                    
                }, completion: nil)
            }
            
            
            
        })
    }
    
    func getFormattedAddress(pm: MKPlacemark) -> String {
        
        var addressString : String = ""
        if let postalAddress = pm.postalAddress {
            let streets = postalAddress.street.split(separator: "–", maxSplits: 1, omittingEmptySubsequences: false)
            
            if streets.count > 1{
                let removedHyphen = streets[1].split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                addressString = streets[0] + " " + removedHyphen[1] + ", " + postalAddress.city + ", " + postalAddress.state
            } else {
                addressString = streets[0] + ", " + postalAddress.city + ", " + postalAddress.state
            }
        }
        
        return addressString
    }
    
    func startRouting() {
        
        
        let options = NavigationRouteOptions(coordinates: [currentLocation.coordinate, destination.coordinate], profileIdentifier: .automobile)
        options.includesSteps = true
        options.locale = Locale(identifier: languageConvert[currentLanguage]!)
        
        // query a navigation route between location coordinates and pass it to VisionARManager
        
        Directions.shared.calculate(options) { [weak self] session, result in
            
            var routes: [MapboxDirections.Route] = []
            
            do {
                routes = try result.get().routes!
            } catch {
                return
            }
            
            guard let route = routes.first else { return }
            
            self?.visionARManager.set(route: Route(route: route))
            
            
            let navigationService = MapboxNavigationService(route: route, routeIndex: 0, routeOptions: options)
            
            navigationService.delegate = self
            let navigationOptions = NavigationOptions(navigationService: navigationService)
            
            let navigationViewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)
            
            navigationViewController.delegate = self
            self!.addChild(navigationViewController)
            self!.view.addSubview(navigationViewController.view)
            navigationViewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                navigationViewController.view.widthAnchor.constraint(equalTo: self!.view.widthAnchor, multiplier: 0.3),
                navigationViewController.view.topAnchor.constraint(equalTo: self!.view.topAnchor, constant: 10),
                navigationViewController.view.heightAnchor.constraint(equalTo: self!.view.heightAnchor, multiplier: 0.24),
                navigationViewController.view.centerXAnchor.constraint(equalTo: self!.view.centerXAnchor, constant: 0)
            ])
            
            navigationViewController.view.layer.cornerRadius = 5
            
            self!.didMove(toParent: self)
            
        }
        
    }
    
    func getStreet(from location: CLLocation, completion: @escaping (([CLPlacemark]?, Error?) -> ())) {
        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(location, completionHandler: {
            placemarks, error -> Void in
            completion(placemarks, error)
        })
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("Available")
        } else {
            print("Denied")
        }
    }
    
    
    func startRecording(_ sender: Any) {
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
            try? visionAManager.startRecording(to: DirPath!.path)
            recording = true
        }
        catch let error as NSError
        {
            print("Unable to create directory \(error.debugDescription)")
        }
        
    }
    
    func stopRecording(_ sender: Any) {
        print("Stopping recording")
        recording = false
        // when you're ready to finish recording
        visionAManager.stopRecording()
    }
    
    
    @IBAction func onRecordPress(_ sender: UIButton) {
        
        if (recording) {
            stopRecording(sender)
            sender.setTitle("Record", for: .normal)
        } else {
            startRecording(sender)
            sender.setTitle("Stop", for: .normal)
        }
        
    }
    
    
}

extension ARNavigationViewController: VisionManagerDelegate {
    
    func visionManager(_ visionManager: VisionManagerProtocol, didUpdateCamera camera: Camera) {
        
        DispatchQueue.main.async {
            self.camera = camera
            if camera.isCalibrated {
                print("Camera calibrated")
                self.calibrated = true
            } else {
                self.calibrated = false
            }
        }
        
    }
    
    func visionManager(_ visionManager: VisionManagerProtocol,
                       didUpdateVehicleState vehicleState: VehicleState) {
        // dispatch to the main queue in order to sync access to `VehicleState` instance
        DispatchQueue.main.async { [weak self] in
            // save the latest state of the vehicle
            
            var prevSpeed: Float = 0
            
            if self?.vehicleState != nil {
                prevSpeed = self!.vehicleState!.speed
            } else {
                self!.timeSinceUpdate = Date().timeIntervalSince1970
            }
            
            self?.vehicleState = vehicleState
            
            
            
            self!.acceleration = (vehicleState.speed - prevSpeed) / Float((Date().timeIntervalSince1970 - (self?.timeSinceUpdate)!))
            
            self!.timeSinceUpdate = Date().timeIntervalSince1970
            
            
            if (self!.previousPOICheck == 0 || Date().timeIntervalSince1970 - self!.previousPOICheck > 2) {
                self!.getNearbyPOIs()
                self!.previousPOICheck = Date().timeIntervalSince1970
            }
            
            self!.updatePOIs()
            
        }
    }
    
    func visionManagerDidCompleteUpdate(_ visionManager: VisionManagerProtocol) {
        // dispatch to the main queue in order to work with UIKit elements
        DispatchQueue.main.async { [weak self] in
            // update UI elements
            self?.updateSpeed()
            self?.updateCollisionDrawing()
            
            
        }
    }
    
    
}

extension ARNavigationViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return languages.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return languages[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentLanguage = languages[row]
        
        unitsLabel.text = "Units".localized(languageConvert[currentLanguage]!)
        metricLabel.text = "Metrics".localized(languageConvert[currentLanguage]!)
        imperialLabel.text = "Imperials".localized(languageConvert[currentLanguage]!)
        languageLabel.text = "Language".localized(languageConvert[currentLanguage]!)
        yourSpeedLabel.text = "Your".localized(languageConvert[currentLanguage]!)
        speedLimitLabel.text = "Limit".localized(languageConvert[currentLanguage]!)
        
    }
    
}

extension ARNavigationViewController: NavigationViewControllerDelegate, NavigationServiceDelegate {
    
    func navigationViewController(_ navigationViewController: NavigationViewController, shouldRerouteFrom location: CLLocation) -> Bool {
        return false
    }
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        navigationController?.popViewController(animated: true)
    }
    
    
}

extension ARNavigationViewController: VisionSafetyManagerDelegate {
    
    func visionManager(_ visionManager: VisionManagerProtocol, didUpdateFrameSignClassifications frameSignClassifications: FrameSignClassifications) {
        if frameSignClassifications.signs.count > 0 {
            for sign in frameSignClassifications.signs {
                
                switch(sign.sign.type) {
                case .speedLimit:
                    if sign.confidNumber < 0.9 {
                        break
                    }
                    
                    if speedLimit == sign.sign.number {
                        break
                    }
                    
                    speedLimit = sign.sign.number
                    
                    DispatchQueue.main.async {
                        self.updateSpeedLimitView(maxSpeed: sign.sign.number)
                    }
                    
                    
                    if (previousAlert == 0 || Date().timeIntervalSince1970 - previousAlert > 4) {
                        DispatchQueue.main.async {
                            
                            if self.units == Units.BOTH {
                                self.speak(text: "Limit".localized(self.languageConvert[self.currentLanguage]!) + String(Int(sign.sign.number)) + "Both".localized(self.languageConvert[self.currentLanguage]!) + String(Int(self.mphToKPH(mph: sign.sign.number))) + "Metric".localized(self.languageConvert[self.currentLanguage]!))
                            } else if self.units == Units.IMPERIAL {
                                self.speak(text: "Limit".localized(self.languageConvert[self.currentLanguage]!) + String(Int(sign.sign.number)) + "Imperial".localized(self.languageConvert[self.currentLanguage]!))
                            } else {
                                self.speak(text: "Limit".localized(self.languageConvert[self.currentLanguage]!) + String(Int(self.mphToKPH(mph: sign.sign.number))) + "Metric".localized(self.languageConvert[self.currentLanguage]!))
                            }
                            
                            
                        }
                        
                        previousAlert = Date().timeIntervalSince1970
                    }
                case .regulatoryStop:
                    if sign.confidType < 0.99 {
                        break
                    }
                    if (previousAlert == 0 || Date().timeIntervalSince1970 - previousAlert > 6) {
                        DispatchQueue.main.async {
                            self.speak(text: "Stop".localized(self.languageConvert[self.currentLanguage]!))
                        }
                        
                        previousAlert = Date().timeIntervalSince1970
                    }
                case .warningRoundabout:
                    if sign.confidType < 0.98 {
                        break
                    }
                    if (previousAlert == 0 || Date().timeIntervalSince1970 - previousAlert > 6) {
                        DispatchQueue.main.async {
                            self.speak(text: "Rotary".localized(self.languageConvert[self.currentLanguage]!) )
                        }
                        
                        previousAlert = Date().timeIntervalSince1970
                    }
                case .regulatoryRoundabout:
                    if sign.confidType < 0.98 {
                        break
                    }
                    if (previousAlert == 0 || Date().timeIntervalSince1970 - previousAlert > 4) {
                        DispatchQueue.main.async {
                            self.speak(text: "Rotary".localized(self.languageConvert[self.currentLanguage]!))
                        }
                        
                        previousAlert = Date().timeIntervalSince1970
                    }
                case .regulatoryYield: break
                    
                case .regulatoryGasStation:
                    print("Gas Station")
                case .regulatorySchoolZone:
                    print("School Zone")
                case .regulatoryPedestriansCrossing:
                    print("Pedestrians")
                case .warningSpeedBump:
                    print("Speed Bump")
                    if sign.confidType < 0.9 {
                        break
                    }
                    if (previousAlert == 0 || Date().timeIntervalSince1970 - previousAlert > 4) {
                        DispatchQueue.main.async {
                            self.speak(text: "Bump".localized(self.languageConvert[self.currentLanguage]!))
                        }
                        
                        previousAlert = Date().timeIntervalSince1970
                    }
                    
                    
                default: break
                }
            }
        }
    }
    
    func visionSafetyManager(_ visionSafetyManager: VisionSafetyManager,
                             didUpdateCollisions collisions: [CollisionObject]) {
        // we will draw collisions with cars only, so we need to filter `CollisionObject`s
        //        let carCollisions = collisions.filter { $0.object.detectionClass == .car || $0.object.detectionClass == .person }
        
        let carCollisions = collisions
        
        // dispatch to the main queue in order to sync access to `[CollisionObject]` array
        DispatchQueue.main.async { [weak self] in
            // update current collisions state
            self?.carCollisions = carCollisions
        }
    }
    
    func mphToKPH(mph: Float) -> Float {
        return mph * 1.609
    }
    
    
}


private extension MapboxVisionARNative.Route {
    /**
     Create `MapboxVisionARNative.Route` instance from `MapboxDirections.Route`.
     */
    convenience init(route: MapboxDirections.Route) {
        var points = [RoutePoint]()
        
        route.legs.forEach {
            $0.steps.forEach { step in
                let maneuver = RoutePoint(
                    coordinate: GeoCoordinate(lon: step.maneuverLocation.longitude,
                                              lat: step.maneuverLocation.latitude),
                    maneuverType: step.maneuverType.visionManeuverType
                )
                points.append(maneuver)
                
                points.append(RoutePoint(coordinate: GeoCoordinate(lon: step.maneuverLocation.longitude, lat: step.maneuverLocation.latitude)))
                
            }
        }
        
        let source = route.legs.first?.source?.name
        let dest = route.legs.last?.source?.name
        
        self.init(points: points,
                  eta: Float(route.expectedTravelTime),
                  sourceStreetName: source ?? "",
                  destinationStreetName: dest ?? "")
    }
}

private extension MapboxDirections.ManeuverType {
    var visionManeuverType: MapboxVisionARNative.ManeuverType {
        switch self {
        case .depart:
            return .depart
        case .turn:
            return .turn
        case .continue:
            return .continue
        case .passNameChange:
            return .newName
        case .merge:
            return .merge
        case .takeOnRamp:
            return .onRamp
        case .takeOffRamp:
            return .offRamp
        case .reachFork:
            return .fork
        case .reachEnd:
            return .endOfRoad
        case .useLane:
            return .none
        case .takeRoundabout:
            return .roundabout
        case .takeRotary:
            return .rotary
        case .turnAtRoundabout:
            return .roundaboutTurn
        case .exitRoundabout:
            return .roundaboutExit
        case .exitRotary:
            return .rotaryExit
        case .heedWarning:
            return .notification
        case .arrive:
            return .arrive
        }
    }
}


// This comment is here to assure the correct rendering of code snippets in a public documentation
