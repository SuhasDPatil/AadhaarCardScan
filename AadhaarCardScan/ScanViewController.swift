//
//  ScanViewController.swift
//  AadhaarCardScan
//
//  Created by Suhas Patil on 21/08/17.
//  Copyright © 2017 Suhas Patil. All rights reserved.
//

import UIKit
import AVFoundation

class ScanViewController: UIViewController {

    @IBOutlet weak var naviBarView: UIView!
    @IBOutlet weak var backButtton: UIButton!
    @IBOutlet weak var navBarTitleLabel: UILabel!
    @IBOutlet weak var bottomButton: UIButton!
    
    
    var captureSession:AVCaptureSession?
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var qrCodeFrameView:UIView?
    let supportedCodeTypes = [AVMetadataObjectTypeUPCECode,
                              AVMetadataObjectTypeCode39Code,
                              AVMetadataObjectTypeCode39Mod43Code,
                              AVMetadataObjectTypeCode93Code,
                              AVMetadataObjectTypeCode128Code,
                              AVMetadataObjectTypeEAN8Code,
                              AVMetadataObjectTypeEAN13Code,
                              AVMetadataObjectTypeAztecCode,
                              AVMetadataObjectTypePDF417Code,
                              AVMetadataObjectTypeQRCode]
    
    var parser : XMLParser = XMLParser()
    let aadhaarDict = NSDictionary()
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Hide navigation (because user can customize navigation bar using topView-naviBarView)
        self.navigationController?.isNavigationBarHidden = true
        // Do any additional setup after loading the view.
    }

    func setupUI() {
        self.naviBarView.frame = CGRect.init(x: 0, y: 0, width: self.view.frame.size.width, height: 70.0)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        switch authStatus {
        case .authorized:
//            SwiftSpinner.show("Loading", animated: true)
            DispatchQueue.main.async {
                self.cameraSetup()
//                SwiftSpinner.hide()
            }
        case .denied:
            alertPromptToAllowCameraAccessViaSettings()
        case .notDetermined:
            permissionPrimeCameraAccess()
        default:
            permissionPrimeCameraAccess()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let connection =  self.videoPreviewLayer?.connection  {
            let currentDevice: UIDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection : AVCaptureConnection = connection
            if previewLayerConnection.isVideoOrientationSupported {
                switch (orientation) {
                case .portrait:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                    break
                case .landscapeRight:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                    break
                case .landscapeLeft:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                    break
                case .portraitUpsideDown:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                    break
                default: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                    break
                }
            }
        }
    }

    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        videoPreviewLayer?.frame = self.view.bounds
    }
    
    func alertPromptToAllowCameraAccessViaSettings() {
        let alert = UIAlertController(title: "Beacon-Merchant Would Like To Access the Camera", message: "", preferredStyle: .alert )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .cancel) { alert in
            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
//            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        })
        present(alert, animated: true, completion: nil)
    }
    
    func permissionPrimeCameraAccess() {
        let alert = UIAlertController( title: "Beacon-Merchant Would Like To Access the Camera", message: "", preferredStyle: .alert )
        let allowAction = UIAlertAction(title: "Allow", style: .default, handler: { (alert) -> Void in
            if (AVCaptureDeviceDiscoverySession.init(deviceTypes: [AVCaptureDeviceType.builtInDualCamera, AVCaptureDeviceType.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.back) != nil) {
                AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [weak self] granted in
                    DispatchQueue.main.async {
                        self?.cameraSetup()
                    }
                })
            }
        })
        alert.addAction(allowAction)
        let declineAction = UIAlertAction(title: "Not Now", style: .cancel) { (alert) in
        }
        alert.addAction(declineAction)
        present(alert, animated: true, completion: nil)
    }
    
    func cameraSetup() {
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video as the media type parameter.
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Initialize the captureSession object.
            captureSession = AVCaptureSession()
            
            // Set the input device on the capture session.
            captureSession?.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            
            // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravityResize
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            
            // Start video capture.
            captureSession?.startRunning()
            
            // Move the message label and top bar to the front
            view.bringSubview(toFront: naviBarView)
            view.bringSubview(toFront: bottomButton)
            view.bringSubview(toFront: navBarTitleLabel)
            view.bringSubview(toFront: backButtton)
            
            // Initialize QR Code Frame to highlight the QR code
            qrCodeFrameView = UIView()
            
            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubview(toFront: qrCodeFrameView)
            }
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - Button Actions

    @IBAction func bottomButtonAction(_ sender: Any) {
        
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        _ = self.navigationController?.popViewController(animated: true)
    }
    
}


// MARK: - AVCaptureMetadataOutputObjectsDelegate Methods

extension ScanViewController : AVCaptureMetadataOutputObjectsDelegate{
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        if metadataObjects == nil || metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if supportedCodeTypes.contains(metadataObj.type) {
            if metadataObj.stringValue != nil {
                let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
                if barCodeObject != nil {
                    qrCodeFrameView?.frame = barCodeObject!.bounds
                    captureSession?.stopRunning()
                    captureSession = nil
                    let alert=UIAlertController(title: "", message: "Aadhaar Card Scanned Success!", preferredStyle: UIAlertControllerStyle.alert);
                    alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: {(action:UIAlertAction) in
                        if metadataObj.stringValue.contains("<?xml") {
                            let adharCardData = metadataObj.stringValue
                            let XMLData = adharCardData?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                            self.parser = XMLParser.init(data:XMLData! as Data)as XMLParser
                            self.parser.delegate = self
                            self.parser.shouldProcessNamespaces = true
                            self.parser.parse()
                        }
                    }));
                    self.present(alert, animated: true, completion: nil);
                }
                else {
                    DispatchQueue.main.async {
                        self.cameraSetup()
                    }
                }
            }
        }
    }
}

extension ScanViewController : XMLParserDelegate {
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "PrintLetterBarcodeData" || elementName == "name" {
            // Get Address
            var landMark = ""
            if let landMarkValue = (attributeDict["lm"]) {
                landMark = landMarkValue
            } else if let landMarkValue1 = (attributeDict["house"]) {
                landMark = landMarkValue1
            } else if let landMarkValue2 = (attributeDict["loc"]) {
                landMark = landMarkValue2
            } else if let landMarkValue3 = (attributeDict["street"]) {
                landMark = landMarkValue3
            }
            let adharAddress = "\(landMark) \(attributeDict["vtc"]!), \(attributeDict["dist"]!), \(attributeDict["state"]!) - \(attributeDict["pc"]!)."
            aadhaarDict.setValue(adharAddress, forKey: "AdharAddress")
            // Get Gender
            aadhaarDict.setValue(attributeDict["gender"], forKey: "AdharGender")
            // Get Full Name
            aadhaarDict.setValue(attributeDict["name"], forKey: "AdharName")
            // Get Aadhaar Number
            aadhaarDict.setValue(attributeDict["uid"], forKey: "AdharNumber")
        } else {
            let alertController = UIAlertController.init(title: "", message: "Could not load QR Code Data", preferredStyle: .alert)
            let scanAgainAction = UIAlertAction.init(title: "Scan Again", style: .default) { (action) in
                self.cameraSetup()
            }
            let cancelAction = UIAlertAction.init(title: "Cancel", style: .default) { (action) in
            }
            alertController.addAction(scanAgainAction)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        let alertController = UIAlertController.init(title: "", message: "Could not load QR Code Data", preferredStyle: .alert)
        let scanAgainAction = UIAlertAction.init(title: "Scan Again", style: .default) { (action) in
            self.cameraSetup()
        }
        let cancelAction = UIAlertAction.init(title: "Cancel", style: .default) { (action) in
        }
        alertController.addAction(scanAgainAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
}


