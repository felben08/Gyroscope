//
//  ViewController.swift
//  Practical Exam
//
//  Created by Felben Abecia on 11/22/21.
//

import UIKit
import AVKit
import AVFoundation
import MapKit
import CoreLocation
import CoreMotion

class ViewController: UIViewController {
    var orientations = UIInterfaceOrientationMask.portrait
    
    // Set Straight Gyro Clearance Angle
    private let clearanceAngle:CGFloat = 20
    
    // Current User Location
    private var userLocation: CLLocation?
    
    // Distance to Reset and Replay the video from the start
    private let tenMeterDistance:CLLocationDistance = 10
    
    private let player = AVPlayer(url: URL(fileURLWithPath: Bundle.main.path(forResource: "WeAreGoingOnBullrun", ofType:"mp4")!))
    var locationManager = CLLocationManager()
    
    // Detect Pause from Shake motion
    var isPausedFromShake: Bool = false
    var motion = CMMotionManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        
        initializeMotionManager()
        
        // Ask for Authorisation from the User.
        self.requestLocationAuthorization()
        
        // To enable motion shake
        _ = self.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.AppUtility.lockOrientation(UIInterfaceOrientationMask.portrait, andRotateTo: UIInterfaceOrientation.portrait)
    }
    
    func initializeMotionManager() {
        motion.deviceMotionUpdateInterval = 0.3
        motion.startDeviceMotionUpdates(to: OperationQueue.current!) { (motion, error) in
            let x:CGFloat = CGFloat((motion?.gravity.x)!)
            let y:CGFloat = CGFloat((motion?.gravity.y)!)
            let z:CGFloat = CGFloat((motion?.gravity.z)!)
            
            let angle:CGFloat = atan2(y, x) + CGFloat(Double.pi / 2)
            let angleDegrees:CGFloat = angle * 180.0 / CGFloat(Double.pi)
            self.setTimeDown(angle: angleDegrees)
            
            let squareRoot:CGFloat = CGFloat(sqrtf(Float(x*x + y*y + z*z)))
            let tiltAngleCGFloat = CGFloat(Double(acosf(Float(z/squareRoot))) * 180.0 / Double.pi - 90.0)
            self.setVolumeDown(volumeDown: tiltAngleCGFloat.sign == .minus)
        }
    }
    
    private func checkToPlay(angle: CGFloat) {
        if abs(angle) <= self.clearanceAngle,
           !self.player.isPlaying,
           !self.isPausedFromShake {
            self.player.play()
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    private func requestLocationAuthorization() {
        self.locationManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.startUpdatingLocation()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Loads and plays a video file after launch
        playVideo()
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        get { return self.orientations }
        set { self.orientations = newValue }
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return UIInterfaceOrientation.portrait
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // set initial user location
        if self.userLocation == nil {
            self.userLocation = manager.location
        }
        
        self.resetVideo(manager)
    }
    
}

extension ViewController {
    // MARK: - Loads and plays a video file after launch.
    private func playVideo() {
        let playerController = PlayerViewController()
        playerController.player = self.player
        playerController.showsPlaybackControls = false
        present(playerController, animated: false) {
            self.player.play()
        }
    }
    
    // MARK: - Reset the video and replay from the start
    // Using the user’s location,
    // a change of 10 meters of the current and previous location will reset the video
    // and replay from the start.
    func resetVideo(_ manager: CLLocationManager) {
        if let currentLocation = manager.location,
           currentLocation.timestamp.timeIntervalSinceNow < 5,
           let distanceMeters = self.userLocation?.distance(from: currentLocation) {
            if distanceMeters > tenMeterDistance {
                self.userLocation = manager.location
                self.player.seek(to: CMTime.zero)
                self.player.play()
            }
        }
    }
    
    // MARK: - A shake of the device should pause the video
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // A shake of the device should pause the video.
        if motion == .motionShake {
            if self.player.isPlaying {
                self.player.pause()
                self.isPausedFromShake = true
            } else {
                self.player.play()
                self.isPausedFromShake = false
            }
        }
    }
    
    // MARK: - Gyroscope events
    
    // X-axis control
    // Rotation along the x-axis should control
    // the volume of the sound
    private func setVolumeDown(volumeDown: Bool) {
        if volumeDown {
            if self.player.volume > 0.0 {
                self.player.volume = self.player.volume - 0.1
            }
        } else {
            if self.player.volume < 1.0 {
                self.player.volume = self.player.volume + 0.1
            }
        }
    }
    
    // Z-axis control
    // Rotation along the z-axis should be able to control the
    // current time where the video is playing
    private func setTimeDown(angle: CGFloat) {
        if abs(angle) > self.clearanceAngle {
            self.player.pause()
             
            let timeDown = angle.sign == .minus
            var seconds : Int64 = Int64(self.player.currentTime().seconds + 1.0)
            if timeDown {
                seconds = Int64(self.player.currentTime().seconds - 1.0)
            }
            
            let preferredTimeScale : Int32 = 1
            
            let seekTime : CMTime = CMTimeMake(value: seconds, timescale: preferredTimeScale)
            if seekTime <= (self.player.currentItem?.asset.duration)! || seconds >= 0 {
                self.player.seek(to: seekTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            }
        } else {
            self.checkToPlay(angle: angle)
        }
    }
    
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
