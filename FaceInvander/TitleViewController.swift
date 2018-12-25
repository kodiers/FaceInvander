//
//  TitleViewController.swift
//  FaceInvander
//
//  Created by Viktor Yamchinov on 25/12/2018.
//  Copyright © 2018 Viktor Yamchinov. All rights reserved.
//

import UIKit

class TitleViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "ViewController") {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

}
