//
//  ViewController.swift
//  HackUMass2020
//
//  Created by Maxwell Hubbard on 12/15/20.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    // Go to load session view controller
    
    @IBAction func toLoad(_ sender: UIButton) {
        self.performSegue(withIdentifier: "toLoad", sender: self)
    }
    
}

