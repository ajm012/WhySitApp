//
//  TimeViewController1.swift
//  WhySit
//
//  Created by Andrew McConnell on 5/29/17.
//  Copyright © 2017 Andrew McConnell. All rights reserved.
//

import Foundation
import UIKit

class WakeUpViewController : UIViewController {
    @IBOutlet weak var wakeUpPicker: UIDatePicker!
    @IBOutlet weak var sleepPicker: UIDatePicker!
    
    var wakeUp: Double = 8.00
    var sleepTime: Double = 20.30
    

    //var storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
    //var nextViewController : ViewController!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //nextViewController = storyBoard.instantiateViewController(withIdentifier: "ViewController") as! ViewController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func wakeUpPickerAction(sender: AnyObject) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH.mm"
        let strDate = dateFormatter.string(from: wakeUpPicker.date)
        wakeUp = Double(strDate)!
    }
    
    @IBAction func sleepPickerAction(sender: AnyObject) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH.mm"
        let strDate = dateFormatter.string(from: sleepPicker.date)
        sleepTime = Double(strDate)!
    }
    
    @IBAction func buttonTapped(sender: AnyObject) {
        
        let myVC = self.storyboard!.instantiateViewController(withIdentifier: "ViewController") as! ViewController
        myVC.time1Passed = wakeUp
        myVC.time2Passed = sleepTime
        let navController = UINavigationController(rootViewController: myVC)
        self.present(navController, animated:true, completion: nil)
    }

}
