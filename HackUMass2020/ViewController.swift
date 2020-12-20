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

    @IBAction func toCreate(_ sender: UIButton) {
        self.performSegue(withIdentifier: "toCreate", sender: self)
    }
    
    @IBAction func toLoad(_ sender: UIButton) {
        self.performSegue(withIdentifier: "toLoad", sender: self)
    }
    
    @IBAction func toTest(_ sender: Any) {
        self.performSegue(withIdentifier: "toTest", sender: self)
    }
}

