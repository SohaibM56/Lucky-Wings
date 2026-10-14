import UIKit
import AVFoundation
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      

      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      let audioChannel = FlutterMethodChannel(name: "com.robinson.luckywings/play_audio",
                                                binaryMessenger: controller.binaryMessenger)
      audioChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
          // Note: this method is invoked on the UI thread.
           guard call.method == "playAudio" else {
             result(FlutterMethodNotImplemented)
             return
           }
          if let args = call.arguments as? Dictionary<String, Any>,
             let path = args["path"] as? String {
              self.playAudio(result: result, path: path)
           } else {
             result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
           }
        })
      
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    var player: AVAudioPlayer?
    var player2: AVAudioPlayer?
    
    private func playAudio(result: FlutterResult, path: String){
        if player != nil && player!.isPlaying {
            let urlString = Bundle.main.path(forResource: path, ofType: "mp3")
            do{
                try AVAudioSession.sharedInstance().setMode(.default)
                try AVAudioSession.sharedInstance().setActive(true,options: .notifyOthersOnDeactivation)
                
                guard let urlString = urlString else {
                    return
                }
                
                player2 = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: urlString))
                guard let player2 = player2 else {
                    return
                }
                player2.prepareToPlay()
                player2.play()
            }catch let error{
                print(error.localizedDescription)
            }
        }else{
            let urlString = Bundle.main.path(forResource: path, ofType: "mp3")
            do{
                try AVAudioSession.sharedInstance().setMode(.default)
                try AVAudioSession.sharedInstance().setActive(true,options: .notifyOthersOnDeactivation)
                
                guard let urlString = urlString else {
                    return
                }
                
                player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: urlString))
                guard let player = player else {
                    return
                }
                player.prepareToPlay()
                player.play()
            }catch let error{
                print(error.localizedDescription)
            }
        }
        
    }
}
