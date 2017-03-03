//
//  ViewController.swift
//  LinkToTLSWithSelfCer
//
//  Created by Veiled phoenix on 2017/1/2.
//  Copyright © 2017年 Veiled phoenix. All rights reserved.
//

import UIKit

let urlString = "URL"

class ViewController: UIViewController, URLSessionTaskDelegate, ASIHTTPRequestDelegate, NSURLConnectionDataDelegate {
    var trustedCertList:NSArray!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: URLSession
    @IBAction func btnURLSessionTap(_ sender: UIButton) {
        //导入客户端证书
        guard let cerPath = Bundle.main.path(forResource: "ca", ofType: "cer") else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cerPath)) else { return }
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else { return }
        trustedCertList = [certificate]
        
        let request = NSMutableURLRequest(url: URL(string: urlString)!)
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        request.httpMethod = "GET"
        
        let task = session.dataTask(with: request as URLRequest, completionHandler:{(data, response, error) -> Void in
            
            if error != nil {
                return
            }
            
            let newStr = String(data: data!, encoding: .utf8)
            print(newStr ?? "")
            
        })
        
        task.resume()
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var err: OSStatus
        var disposition: Foundation.URLSession.AuthChallengeDisposition = Foundation.URLSession.AuthChallengeDisposition.performDefaultHandling
        var trustResult: SecTrustResultType = .invalid
        var credential: URLCredential? = nil
        
        //获取服务器的trust object
        let serverTrust: SecTrust = challenge.protectionSpace.serverTrust!
        
        //将读取的证书设置为serverTrust的根证书
        err = SecTrustSetAnchorCertificates(serverTrust, trustedCertList)
        
        if err == noErr {
            //通过本地导入的证书来验证服务器的证书是否可信
            err = SecTrustEvaluate(serverTrust, &trustResult)
        }
        
        if err == errSecSuccess && (trustResult == .proceed || trustResult == .unspecified) {
            //认证成功，则创建一个凭证返回给服务器
            disposition = Foundation.URLSession.AuthChallengeDisposition.useCredential
            credential = URLCredential(trust: serverTrust)
        } else {
            disposition = Foundation.URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge
        }
        
        //回调凭证，传递给服务器
        completionHandler(disposition, credential)
        
        //如果不论安全性，不想验证证书是否正确。那上面的代码都不需要，直接写下面这段即可
//        let serverTrust: SecTrust = challenge.protectionSpace.serverTrust!
//        SecTrustSetAnchorCertificates(serverTrust, trustedCertList)
//        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
   
    // MARK: ASIHTTPRequest
    @IBAction func btnASIHTTPRequestTap(_ sender: UIButton) {
        //鸣谢：http://bewithme.iteye.com/blog/1999031
        let url = URL(string: urlString)
        let request = ASIHTTPRequest.request(with: url) as! ASIHTTPRequest
        
        //导入客户端证书
        guard let cerPath = Bundle.main.path(forResource: "ca", ofType: "p12") else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cerPath)) else { return }
        
        var identity: SecIdentity? = nil
        if self.extractIdentity(outIdentity: &identity, cerData: data) {
            request.setClientCertificateIdentity(identity!)
            
            request.delegate = self
            request.startAsynchronous()
        }
        
        //如果不论安全性，不想验证证书是否正确。那上面的代码都不需要，直接写下面这段即可
//        request.validatesSecureCertificate = false
//        request.delegate = self
//        request.startAsynchronous()
    }
    
    func requestFinished(_ request: ASIHTTPRequest) {
        guard let responseString = String.init(data: request.responseData(), encoding: .utf8) else { return }
        
        print(responseString)
    }
    
    func requestFailed(_ request: ASIHTTPRequest) {
        print(request.error)
    }
    
    func extractIdentity(outIdentity: inout SecIdentity?, cerData: Data) -> Bool {
        var securityError = errSecSuccess
        //这个字典里的value是证书密码
        let optionsDictionary: Dictionary<String, CFString>? = [kSecImportExportPassphrase as String: "" as CFString]
        
        var items: CFArray? = nil

        securityError = SecPKCS12Import(cerData as CFData, optionsDictionary as! CFDictionary, &items)
        
        if securityError == 0 {
            let myIdentityAndTrust = items as! NSArray as! [[String:AnyObject]]
            outIdentity = myIdentityAndTrust[0][kSecImportItemIdentity as String] as! SecIdentity?
        } else {
            print(securityError)
            return false
        }
        
        return true
    }
    
    // MARK: AFNetworking
    @IBAction func btnAFNetworkingTap(_ sender: UIButton) {
        guard let cerPath = Bundle.main.path(forResource: "ca", ofType: "cer") else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cerPath)) else { return }
        //guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else { return }
        var certSet: Set<Data> = []
        certSet.insert(data)
        
        let manager = AFHTTPSessionManager(baseURL: URL(string: urlString))
        manager.responseSerializer = AFHTTPResponseSerializer()
        //pinningMode设置为证书形式
        manager.securityPolicy = AFSecurityPolicy.init(pinningMode: .certificate, withPinnedCertificates: certSet)
        //allowInvalidCertificates必须设为true
        manager.securityPolicy.allowInvalidCertificates = true
        manager.securityPolicy.validatesDomainName = true
        
        manager.get(urlString, parameters: nil,
                    progress: {(pro: Progress) -> () in
                        
        },
                    success: {(dataTask: URLSessionDataTask?, responseData: Any) -> () in
                        print(String(data: responseData as! Data, encoding: .utf8)!)
        },
                    failure: {(dataTask: URLSessionDataTask?, error: Error) -> () in
                        print(error)
        })
    }
    
    // MARK: NSURLConnection
    @IBAction func btnNSURLConnectionTap(_ sender: UIButton) {
        //导入客户端证书
        guard let cerPath = Bundle.main.path(forResource: "ca", ofType: "cer") else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cerPath)) else { return }
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else { return }
        trustedCertList = [certificate]
        
        let request: URLRequest = URLRequest.init(url: URL(string: urlString)!)

        _ = NSURLConnection(request: request, delegate: self, startImmediately: true)
    }
    
    func connection(_ connection: NSURLConnection, didReceive data: Data) {
        print(String(data: data, encoding: .utf8)!)
    }
    
    func connection(_ connection: NSURLConnection, willSendRequestFor challenge: URLAuthenticationChallenge) {
        var trustResult: SecTrustResultType = .invalid
        
        let serverTrust: SecTrust = challenge.protectionSpace.serverTrust!
        var err: OSStatus = SecTrustSetAnchorCertificates(serverTrust, trustedCertList)
        
        if err == noErr {
            //通过本地导入的证书来验证服务器的证书是否可信
            err = SecTrustEvaluate(serverTrust, &trustResult)
        }
        
        if err == errSecSuccess && (trustResult == .proceed || trustResult == .unspecified) {
            //认证成功，则创建一个凭证返回给服务器
            challenge.sender?.use(URLCredential(trust: serverTrust), for: challenge)
            challenge.sender?.continueWithoutCredential(for: challenge)
        } else {
            challenge.sender?.cancel(challenge)
        }
        
        //如果不论安全性，不想验证证书是否正确。那上面的代码都不需要，直接写下面这段即可
//        let serverTrust: SecTrust = challenge.protectionSpace.serverTrust!
//        SecTrustSetAnchorCertificates(serverTrust, trustedCertList)
//        challenge.sender?.use(URLCredential(trust: serverTrust), for: challenge)
//        challenge.sender?.continueWithoutCredential(for: challenge)
    }
    
    // MARK: RestKit
    @IBAction func btnRestKitTap(_ sender: UIButton) {
        RKMIMETypeSerialization.registerClass(RKNSJSONSerialization.self, forMIMEType: "text/html")
        
        let httpClient = AFRKHTTPClient.init(baseURL: URL(string: urlString))
        let manager = RKObjectManager.init(httpClient: httpClient)
        manager?.httpClient.defaultSSLPinningMode = AFRKSSLPinningModeCertificate
        
        let statusCodes = RKStatusCodeIndexSetForClass(.successful)
        //mapping这么初始化是不够的，需要的自己完善
        let mapping = RKMapping()
        mapping.forceCollectionMapping = false
        let responseDescriptor = RKResponseDescriptor(mapping: RKMapping(), method: .any, pathPattern: nil, keyPath: nil, statusCodes: statusCodes)
        
        manager?.addResponseDescriptor(responseDescriptor)
        
        manager?.getObjectsAtPath(urlString, parameters: nil, success: {(operation: RKObjectRequestOperation?, result: RKMappingResult?) in
            print(result ?? "")
        }, failure: { (operation: RKObjectRequestOperation?, error: Error?) in
            print(error ?? "")
        })
    }
    
    // MARK: WEBVIEW
    @IBAction func btnWebViewTap(_ sender: UIButton) {
//        self.performSegue(withIdentifier: "showWebView", sender: nil)
        
        //导入客户端证书
        guard let cerPath = Bundle.main.path(forResource: "ca", ofType: "cer") else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cerPath)) else { return }
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else { return }
        trustedCertList = [certificate]
        
        let request = NSMutableURLRequest(url: URL(string: urlString)!)
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        request.httpMethod = "GET"
        
        let task = session.dataTask(with: request as URLRequest, completionHandler:{(data, response, error) -> Void in
            
            if error != nil {
                return
            }
            
            let newStr = String(data: data!, encoding: .utf8)
            OperationQueue.main.addOperation {
                self.performSegue(withIdentifier: "showWebView", sender: newStr)
            }
        })
        
        task.resume()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        self.view.endEditing(true)
        
        if segue.identifier == nil {
            return
        }
        
        let nextViewController = segue.destination as! WebViewController
        nextViewController.pageString = sender as! String
    }
}

