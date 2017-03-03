//
//  WebViewController.swift
//  LinkToTLSWithSelfCer
//
//  Created by veiled phoenix on 03/03/2017.
//  Copyright © 2017 Veiled phoenix. All rights reserved.
//

import UIKit

class WebViewController: UIViewController {
    
    @IBOutlet weak var MainWebView: UIWebView!
    
    var pageString: String!

    override func viewDidLoad() {
        super.viewDidLoad()

        MainWebView.loadHTMLString(pageString, baseURL: nil)
        MainWebView.scalesPageToFit = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
