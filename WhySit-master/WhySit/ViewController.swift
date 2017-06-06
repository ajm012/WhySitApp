//
//  ViewController.swift
//  WhySit
//
//  Created by Andrew McConnell on 4/25/17.
//  Copyright © 2017 Andrew McConnell. All rights reserved.
//
// TODO:
// update() can be called from background now

import UIKit
import CoreLocation
import ResearchKit
import CoreBluetooth
import UserNotifications
import UserNotificationsUI
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    let requestIdentifier = "SampleRequest"
    let SERVER = "http://murphy.wot.eecs.northwestern.edu/~ajm012/WhySitServer.py"
    
    @IBOutlet weak var survey: UIButton!
    @IBOutlet weak var submit: UIButton!
    @IBOutlet weak var latitude: UILabel!
    @IBOutlet weak var longitude: UILabel!
    @IBOutlet weak var id: UILabel!
    @IBOutlet weak var wake: UILabel!
    @IBOutlet weak var sleep: UILabel!
    
    let arrayOfServices: [CBUUID] = [CBUUID(string: "FEAA")]//[CBUUID(string: "FEAA"), CBUUID(string: "00000000-0000-1000-8000-00805F9B34FB")]
    let state = UIApplication.shared.applicationState
    
    var centralManager: CBCentralManager?
    var peripherals = Array<CBPeripheral>()
    let uuid = NSUUID().uuidString
    
    var count = 1
    
    var locationManager: CLLocationManager!
    var timer: Timer?
    
    var locationDone = false
    var notificationTriggeredThisWindow = false
    var lastNotification: Double = 0
    var wakeUpTime = 8.00
    var sleepTime = 20.50
    var windowLength: Double = 0
    
    var time1Passed = Double()
    var time2Passed = Double()
    var noteTriggeredCount = 0
    
    var player:AVAudioPlayer!
    
    var filePath:URL!
    let home = NSHomeDirectory()
    
    struct defaultsKeys {
        static let id = "userId"
        static let path = "docsPath"
    }
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        
        let defaults = UserDefaults.standard
        
        
        // check if id/doc path already set
        if let stringOne = defaults.string(forKey: defaultsKeys.id) {
            print(stringOne) // Some String Value
            let index = stringOne.index(stringOne.startIndex, offsetBy: 8)
            let userId = stringOne.substring(to: index)
            id.text = userId
            if URL(string: defaults.string(forKey: defaultsKeys.path)!) != nil {
                let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
                filePath = documentsPath.appendingPathComponent(stringOne)
                //filePath = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/" + stringOne + "/Documents")
                do {
                    print("Creating \(filePath.path)")
                    try FileManager.default.createDirectory(atPath: filePath.path, withIntermediateDirectories: true, attributes: nil)
                } catch let error as NSError {
                    print(error.localizedDescription);
                }
            } else {
                let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
                filePath = documentsPath.appendingPathComponent(stringOne)
                //filePath = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/" + uuid + "/Documents")
                do {
                    try FileManager.default.createDirectory(atPath: filePath.path, withIntermediateDirectories: true, attributes: nil)
                } catch let error as NSError {
                    print(error.localizedDescription);
                }
            }
        } else {
            let index = uuid.index(uuid.startIndex, offsetBy: 8)
            let userId = uuid.substring(to: index)
            id.text = userId
            let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
            filePath = documentsPath.appendingPathComponent(uuid)
            //filePath = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/" + uuid + "/Documents")
            do {
                try FileManager.default.createDirectory(atPath: filePath.path, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                print(error.localizedDescription);
            }
            defaults.set(uuid, forKey: defaultsKeys.id)
            defaults.set(filePath, forKey: defaultsKeys.path)
        }
        
        
        //survey.isEnabled = false
        submit.isEnabled = false
        
        
        
        wake.text = String(format: "%.2f", time1Passed)
        sleep.text = String(format: "%.2f", time2Passed)
        
        let wakeHour = round(time1Passed)
        let wakeMin = time1Passed - wakeHour
        let sleepHour = round(time2Passed)
        let sleepMin = time2Passed - sleepHour
        let wakeFrac = wakeMin / 0.6
        let sleepFrac = sleepMin / 0.6
        
        wakeUpTime = wakeHour + wakeFrac
        sleepTime = sleepHour + sleepFrac
        
        print("\(wakeUpTime)")
        print("\(sleepTime)")
        
        print("View did load")
        windowLength = (sleepTime - wakeUpTime) / 5
        print("\(windowLength)")
        
        // PLAY SILENT AUDIO FOR INFINITE BACKGROUND TIME
        let path = Bundle.main.path(forResource: "silence-10sec", ofType: "mp3")!
        let audioUrl = NSURL(fileURLWithPath: path)
        do
        {
            player = try AVAudioPlayer(contentsOf: audioUrl as URL)
            // if you want it play infinite time: player.numberOfLoops = (-1)
            player.numberOfLoops = (-1)
            player.prepareToPlay()
        }
        catch
        {
            //catching the error.
        }
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)
        } catch {
            //catching the error.
        }
        
        // check for stored surveys in case of crash
        // loop until file not found
        
        while true {
            //let DocumentDirURL =  try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: NSURL() as URL, create: false)
            let fileName = "Survey" + String(count)
            let fileURL = filePath.appendingPathComponent(fileName).appendingPathExtension("csv")
            print("Checking for \(fileURL.absoluteURL)")
            let fileManager = FileManager.default
            
            // Check if file exists, given its path
            
            if fileManager.fileExists(atPath: fileURL.path) {
                print("File found")
                count += 1
                continue // find maximum survey num taken
            } else { // if SurveyX not found, set count to X
                print("File not found")
                break
            }
        }
        if count > 1 {
            submit.isEnabled = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
        
        
    }
    
    func determineMyCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        //locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let userLocation:CLLocation = locations[0] as CLLocation
        longitude.text = String(format: "%f", userLocation.coordinate.longitude)
        latitude.text = String(format: "%f", userLocation.coordinate.latitude)
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func triggerSurvey(){
        
        print("notification will be triggered in five seconds..Hold on tight")
        let content = UNMutableNotificationContent()
        content.title = "WhySit Survey"
        content.subtitle = "A Survey Has Been Made Available in the WhySit App"
        content.body = "Please navigate to the app and fill out the available survey."
        content.sound = UNNotificationSound.default()
        
        //To Present image in notification
        if let path = Bundle.main.path(forResource: "monkey", ofType: "png") {
            let url = URL(fileURLWithPath: path)
            
            do {
                let attachment = try UNNotificationAttachment(identifier: "sampleImage", url: url, options: nil)
                content.attachments = [attachment]
            } catch {
                print("attachment not found.")
            }
        }
        
        // Deliver the notification in five seconds.
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 7*60.0, repeats: true)
        let request = UNNotificationRequest(identifier:requestIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().add(request){(error) in
            
            if (error != nil){
                
                print(error?.localizedDescription as Any)
            }
        }
    }
    
    @IBAction func surveyTapped(sender : AnyObject) {
        let taskViewController = ORKTaskViewController(task: SurveyTask, taskRun: nil)
        taskViewController.delegate = self
        self.present(taskViewController, animated: true, completion: nil)
    }
    
    func update() {
        if (noteTriggeredCount == count) {
            print("User failed to respond in time...removing notifications, cancelling survey")
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        
            //let DocumentDirURL =  try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: NSURL() as URL, create: true)
            let fileName = "Survey" + String(count)
            let fileURL = filePath.appendingPathComponent(fileName).appendingPathExtension("csv")
            var csvText = "Q1=NA&Q2=NA&Q3=NA&Q4=NA&Q5=NA&Q6a=NA&Q6b=NA&Q6c=NA&Qcd=NA&Q7a=NA&Q7b=NA&"
            csvText += "latitude=" + latitude.text! + "&"
            csvText += "longitude=" + longitude.text! + "&"
            csvText += "id=" + id.text! + "&"
            let date = Date()
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let minutes = calendar.component(.minute, from: date)
            let seconds = calendar.component(.second, from: date)
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            let current_date = formatter.string(from: date)
            csvText += "time=" + current_date + " "
            csvText += (hour as NSNumber).stringValue + ":" + (minutes as NSNumber).stringValue
            csvText += ":" + (seconds as NSNumber).stringValue
        
            if FileManager.default.fileExists( atPath: fileURL.path ) == false
            {
                print("Creating \(fileURL.path)")
                let success = FileManager.default.createFile(atPath: fileURL.path, contents: csvText.data(using: .utf8),    attributes: nil)
                print("Success = \(success)")
            }
            //survey.isEnabled = false
            count += 1
        }
    }
}

extension ViewController : ORKTaskViewControllerDelegate {
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        //Handle results with taskViewController.result
        submit.isEnabled = false
        determineMyCurrentLocation()
        
        if (taskViewController.task?.identifier == "SurveyTask" && reason == .completed) {
            print("Starting results")
            
            let fileName = "Survey" + String(count)
            count += 1
            if count > 1 {submit.isEnabled = true}
            //let DocumentDirURL =  try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: NSURL() as URL, create: true)
            
            let fileURL = filePath.appendingPathComponent(fileName).appendingPathExtension("csv")
            
            //var csvText = "Q1,Q2,Q3,Q4,Q5,Q6a,Q6b,Q6c,Q6d,Q7a,Q7b,Latitude,Longitude\r\n"
            var csvText = ""
            
            let taskResultValue = taskViewController.result
            if let q1StepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep")
            {
                let ans = (q1StepResult.results?[0].value(forKey: "answer")! as! NSArray)[0]
                print("Question 1 Answer: \(ans)")
                csvText += "Q1="+(ans as AnyObject).stringValue + "&"
            }
            if let q2StepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep2")
            {
                let ans = (q2StepResult.results?[0].value(forKey: "answer")! as! NSArray)[0]
                print("Question 2 Answer: \(ans)")
                csvText += "Q2="+(ans as AnyObject).stringValue + "&"
            }
            else {csvText += "Q2=NA&"}
            if let q3StepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep3")
            {
                let arr = q3StepResult.results?[0].value(forKey: "answer")! as! NSArray
                var ans = "("
                for val in arr {
                    print("Question 3 Answer: \(val)")
                    ans += "Q3="+(val as! NSNumber).stringValue + "/"
                }
                csvText += ans
                csvText += ")&"
            }
            else {csvText += "Q3=NA&"}
            if let q4StepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep4")
            {
                let ans = (q4StepResult.results?[0].value(forKey: "answer")! as! NSArray)[0]
                print("Question 4 Answer: \(ans)")
                csvText += "Q4="+(ans as AnyObject).stringValue + "&"
            }
            else {csvText += "Q4=NA&"}
            if let q5StepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep5")
            {
                let arr = q5StepResult.results?[0].value(forKey: "answer")! as! NSArray
                //let ans = (arr as AnyObject).stringValue + ","
                var ans = "("
                for val in arr {
                    print("Question 5 Answer: \(val)")
                    ans += (val as! NSNumber).stringValue + "/"
                }
                csvText += "Q5="+ans
                csvText += ")&"
            }
            if let q6aStepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep6a")
            {
                let ans = (q6aStepResult.results?[0].value(forKey: "answer")! as! NSArray)[0]
                print("Question 6a Answer: \(ans)")
                csvText += "Q6a="+(ans as AnyObject).stringValue + "&"
            }
            else {csvText += "Q6a=NA&"}
            if let q6bStepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep6b")
            {
                let ans = (q6bStepResult.results?[0].value(forKey: "answer")! as! NSArray)[0]
                print("Question 6b Answer: \(ans)")
                csvText += "Q6b="+(ans as AnyObject).stringValue + "&"
            }
            else {csvText += "Q6b=NA&"}
            if let q6cStepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep6c")
            {
                let ans = (q6cStepResult.results?[0].value(forKey: "answer")! as! NSArray)[0]
                print("Question 6c Answer: \(ans)")
                csvText += "Q6c="+(ans as AnyObject).stringValue + "&"
            }
            else {csvText += "Q6c=NA&"}
            if let q6dStepResult = taskResultValue.stepResult(forStepIdentifier: "TextChoiceQuestionStep6d")
            {
                let ans = (q6dStepResult.results?[0].value(forKey: "answer")! as! NSArray)[0]
                print("Question 6d Answer: \(ans)")
                csvText += "Q6d="+(ans as AnyObject).stringValue + "&"
            }
            else {csvText += "Q6d=NA&"}
            if let e1dStepResult = taskResultValue.stepResult(forStepIdentifier: "SliderQuestion7a")
            {
                let ans = (e1dStepResult.results?[0].value(forKey: "answer")! as! NSNumber).stringValue
                print("Question 7a Answer: \(ans)")
                csvText += "Q7a=" + ans + "&"
            }
            if let e2StepResult = taskResultValue.stepResult(forStepIdentifier: "SliderQuestion7b")
            {
                let ans = (e2StepResult.results?[0].value(forKey: "answer")! as! NSNumber).stringValue
                print("Question 7b Answer: \(ans)")
                csvText += "Q7b" + ans + "&"
            }
            csvText += "latitude="+latitude.text! + "&"
            csvText += "longitude="+longitude.text! + "&"// + "\n"
            csvText += "id=" + id.text! + "&"
            
            let date = Date()
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let minutes = calendar.component(.minute, from: date)
            let seconds = calendar.component(.second, from: date)
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            let current_date = formatter.string(from: date)
            csvText += "time=" + current_date + " "
            csvText += (hour as NSNumber).stringValue + ":" + (minutes as NSNumber).stringValue
            csvText += ":" + (seconds as NSNumber).stringValue
            
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
            print("\(FileManager.default.fileExists(atPath: filePath.path))")
            if FileManager.default.fileExists( atPath: fileURL.path ) == false
            {
                print("Creating \(fileURL.path)")
                let success = FileManager.default.createFile(atPath: fileURL.path, contents: csvText.data(using: .utf8), attributes: nil)
                print("Success = \(success)")
            }
            //print("\(FileManager.default.fileExists( atPath: fileURL.path ))")
            /*
            do {
                // Write to the file
                try csvText.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            } catch let error as NSError {
                print("Failed writing to URL: \(fileURL), Error: " + error.localizedDescription)
            }*/
            
        }
        //survey.isEnabled = false
        locationManager.stopUpdatingLocation()
        centralManager?.scanForPeripherals(withServices: arrayOfServices, options: nil)
        taskViewController.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func submitTapped(sender : AnyObject) {
        submit.isEnabled = false
        for x in 1...count-1 {
            var readString = "" // Used to store the file contents
            let fileName = "Survey" + String(x)
            //let DocumentDirURL =  try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: NSURL() as URL, create: true)
            let fileURL = filePath.appendingPathComponent(fileName).appendingPathExtension("csv")
            do {
                // Read the file contents
                readString = try String(contentsOf: fileURL)
            } catch let error as NSError {
                print("Failed reading from URL: \(fileURL), Error: " + error.localizedDescription)
            }
            sendToServer(packet: "survey="+String(x)+"&"+readString, url: fileURL)
            //try! FileManager.default.removeItem(atPath: fileURL.path)
        }
        count = 1
    }
    
    func sendToServer(packet: String, url: URL) {
        print("Packet = \(packet)")
        var request = URLRequest(url: URL(string: SERVER)!)
        request.httpMethod = "POST"
        let postString = packet
        request.httpBody = postString.data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                // check for fundamental networking error
                print("error=\(error)")
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(response)")
                self.submit.isEnabled = true // allow user to try again
            } else { // if HTTP statusCode is 200, delete file
                print("response = \(response)")
                let fileManager = FileManager.default
                do {
                    print("Removing survey")
                    try fileManager.removeItem(atPath: url.path)
                }
                catch let error as NSError {
                    print("Ooops! Something went wrong: \(error)")
                }
            }
            let responseString = String(data: data, encoding: .utf8)
            print("responseString = \(responseString)")
        }
        task.resume()
    }

}

extension ViewController: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {

        if (central.state == .poweredOn){
            print("Scanning")
            self.centralManager?.scanForPeripherals(withServices: arrayOfServices, options: nil)
        }
        else {
            print("BLE not enabled")
        }
    }
    
    // Returns true if the last notification was sent in a past window
    func schedulerDaemonCheck() -> Bool {
        // check if currently inside window
        if convertCurrentTimeToDouble() > sleepTime || convertCurrentTimeToDouble() < wakeUpTime {
            return false
        }
        // check if notification is appropriate
        let current = convertCurrentTimeToDouble() - wakeUpTime
        let last = lastNotification - wakeUpTime
        if NSInteger(current / windowLength) - NSInteger(last / windowLength) > 0 {
            return true
        }
        return false
    }
    
    func convertCurrentTimeToDouble() -> Double {
        let hour: Double = Double(Calendar.current.component(.hour, from: Date()))
        let minute: Double = Double(Calendar.current.component(.minute, from: Date()))
        let minute_frac = minute / 60.0
        return (hour + minute_frac)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("...")
        print("NotificationTriggeredThisWindow: \(notificationTriggeredThisWindow)")
        print("Count: \(count)")
        // Check if survey should be enabled
        //let hour = Calendar.current.component(.hour, from: Date())
        //print("Time: \(hour)")
        /*if (hour % 3) - (lastNotification % 3) > 0 {
            notificationTriggeredThisWindow = false
        }*/
        if schedulerDaemonCheck() {
            print("Scheduler daemon says to allow survey")
            notificationTriggeredThisWindow = false
            survey.isEnabled = true
        }
        else {
            print("Ignoring signal")
            centralManager?.scanForPeripherals(withServices: arrayOfServices, options: nil)
        }
 
        if (peripheral.name != nil && !notificationTriggeredThisWindow) {
            peripheral.discoverServices(arrayOfServices)
            triggerSurvey()
            noteTriggeredCount = count
            lastNotification = convertCurrentTimeToDouble()
            self.timer = Timer.scheduledTimer(timeInterval: 20*60.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: false)
            print("Peripheral discovered")
            print(peripheral.name! as Any)
            print("\(advertisementData)".components(separatedBy: "\n"))
            //peripherals.append(peripheral)
            //print("Connecting...")
            //peripheral.delegate = self // added
            //centralManager?.connect(peripheral, options: nil)
            print(peripheral.identifier)
            //centralManager?.stopScan()
            survey.isEnabled = true
            notificationTriggeredThisWindow = true
        }
    }
    
    // Called when connection succeeded
    func centralManager(central: CBCentralManager,
                        didConnectPeripheral peripheral: CBPeripheral) {
        print("Connected!")
    }
    // Called when connection failed
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("Failed…")
    }
}

extension ViewController : UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("Tapped in notification")
    }
    
    //This is key callback to present notification while the app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("Notification being triggered")
        //You can either present alert ,sound or increase badge while the app is in foreground too with ios 10
        //to distinguish between notifications
        if notification.request.identifier == requestIdentifier{
            
            completionHandler( [.alert,.sound,.badge])
            
        }
    }
}


