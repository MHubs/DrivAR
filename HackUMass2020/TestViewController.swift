import CoreLocation
import MapboxDirections
import MapboxVision
import MapboxVisionAR
import MapboxVisionARNative
import UIKit
import Speech
import AVFoundation
import MapKit
import Contacts

/**
 * "AR Navigation" example demonstrates how to display navigation route projected on the surface of the road.
 */

class TestViewController: UIViewController, SFSpeechRecognizerDelegate {
    var videoSource: CameraVideoSource!
    var visionManager: VisionManager!
    var visionARManager: VisionARManager!
    
    var locManager = CLLocationManager()
    var currentLocation: CLLocation!
    var destination: CLLocation!
    
    let visionARViewController = VisionARViewController()
    private let audioEngine = AVAudioEngine()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @IBOutlet weak var backView: UIView!
    @IBOutlet weak var speechButton: UIImageView!
    
    @IBOutlet weak var destinationView: UIVisualEffectView!
    
    @IBOutlet weak var destinationLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    var recording: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addARView()
        
        // create a video source obtaining buffers from camera module
        videoSource = CameraVideoSource()
        
        // create VisionManager with video source
        visionManager = VisionManager.create(videoSource: videoSource)
        // create VisionARManager
        visionARManager = VisionARManager.create(visionManager: visionManager)
        // configure AR view to display AR navigation
        visionARViewController.set(arManager: visionARManager)
        
        
        //GPS Location use
        locManager.requestAlwaysAuthorization()
        locManager.requestWhenInUseAuthorization()
        
        destinationView.alpha = 0
        destinationView.layer.cornerRadius = destinationView.frame.width / 8
        destinationView.clipsToBounds = true
        
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
        addChild(visionARViewController)
        backView.addSubview(visionARViewController.view)
        visionARViewController.didMove(toParent: self)
    }
    
    deinit {
        // free up resources by destroying modules when they're not longer used
        visionARManager.destroy()
        // free up VisionManager's resources, should be called after destroing its module
        visionManager.destroy()
    }
    
    @objc func onMicrophoneTap() {
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            
        } else {
            do {
                try startSpeechRecognition()
            } catch {
            }
        }
        
    }
    
    
    
    func startSpeechRecognition() throws  {
        
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
                print("Text \(result.bestTranscription.formattedString)")
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                
                if isFinal {
                    
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
            destinationLabel.text = "Try Again"
            addressLabel.text = "Could not understand destination"
        } else {
            destinationLabel.text = mapItem!.name
            addressLabel.text = getFormattedAddress(pm: mapItem!.placemark)
        }
        
        
        
        UIView.animate(withDuration: 2, animations: {
            
            self.destinationView.alpha = 1
            
        }, completion: { done in
            
            UIView.animate(withDuration: 2, delay: 5, options: UIView.AnimationOptions.allowAnimatedContent, animations: {
                
                self.destinationView.alpha = 0
                
            }, completion: nil)
            
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
        
        let options = RouteOptions(coordinates: [currentLocation.coordinate, destination.coordinate], profileIdentifier: .automobile)
        options.includesSteps = true
        
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
            try? visionManager.startRecording(to: DirPath!.path)
        }
        catch let error as NSError
        {
            print("Unable to create directory \(error.debugDescription)")
        }
        
    }
    
    func stopRecording(_ sender: Any) {
        print("Stopping recording")
        // when you're ready to finish recording
        visionManager.stopRecording()
    }
    
    @IBAction func onRecordPress(_ sender: Any) {
        
        if (recording) {
            stopRecording(sender)
            (sender as! UIButton).setTitle("Record", for: .normal)
        } else {
            startRecording(sender)
            (sender as! UIButton).setTitle("Stop", for: .normal)
        }
        
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
