//
//  ViewController.swift
//  WhoIsMyRepresentative
//
//  Created by Parker Play  on 3/14/16.
//  Copyright © 2016 Parker Planners. All rights reserved.
//

import UIKit
import Foundation
import CoreLocation

class CallViewController: UIViewController {
    
    // IBOulets
    @IBOutlet weak var searchButton: UIButton! {
        didSet {
            searchButton.layer.cornerRadius = searchButton.frame.size.height/2
        }
    }
    
    @IBOutlet weak var locationButton: UIButton! {
        didSet {
            locationButton.layer.cornerRadius = locationButton.frame.size.height/2
        }
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var zipCodeField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var arrayForRepInfo: NSArray = []
    var locationManager: CLLocationManager!
    
    // VC Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        zipCodeField.delegate = self
        tableView.tableFooterView = UIView()
        activityIndicator.isHidden = true
        setUpLocationManager()
    }
    
    func setUpLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // IBActions
    @IBAction func searchRepApi(_ sender: Any) {
        // Dismiss keyboard
        view.endEditing(true)
        // Clear table view data
        arrayForRepInfo = []
        tableView.reloadData()
        // Check to see that the zip input is 5 digits
        let zipCodeString = zipCodeField.text
        if let zipCount = zipCodeString?.count {
            if zipCount < 5 || zipCount > 6 {
                showFailAlert(title: "ZIP Code Not Found", message: "US ZIP Codes are 5 digits.")
            } else {
                activityIndicator.startAnimating()
                activityIndicator.isHidden = false
                apiCallForReps()
            }
        }
    }

    @IBAction func getZipFromLocation(_ sender: Any) {
        populateZipField()
    }
    
    // Networking
    func apiCallForReps() {
        guard let zipCode = zipCodeField.text else { return }
        let urlString = NSString(format: "http://whoismyrepresentative.com/getall_mems.php?zip=%@&output=json", zipCode)
        guard let url = NSURL(string: urlString as String) else { return }
        let request = NSURLRequest(url: url as URL)
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            guard let data = data else { return }
            do {
                let JSON = try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions(rawValue: 0))
                guard let JSONDictionary :NSDictionary = JSON as? NSDictionary else { return }
                if let customerArray = JSONDictionary.value(forKey: "results") as? NSArray {
                    self.arrayForRepInfo = customerArray
                }
            }
            catch let JSONError as NSError {
                DispatchQueue.main.sync(execute: {
                    self.activityIndicator.stopAnimating()
                    self.activityIndicator.isHidden = true
                    self.showFailAlert(title: "ZIP Code Not Found", message: "Please enter valid US ZIP Code")
                    print(JSONError.localizedDescription)
                })
                
            }
            
            DispatchQueue.main.sync(execute: {
                self.tableView.reloadData()
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
            })

        }
        task.resume()
    }
    
    func showFailAlert(title: String, message: String) {
        let alertTitle = title
        let alertMessage = message
        let alertOk = "Ok"
        
        let refreshAlert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
        
        refreshAlert.addAction(UIAlertAction(title: alertOk, style: .default, handler: { (action: UIAlertAction!) in
            refreshAlert .dismiss(animated: true, completion: nil)
            
        }))
        present(refreshAlert, animated: true, completion: nil)
    }
    
}

// Textfield delegate
extension CallViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        searchRepApi(self)
        return true
    }
}

 // UITableView DataSource and Delegate
extension CallViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView:UITableView, numberOfRowsInSection section:Int) -> Int {
        return arrayForRepInfo.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "RepTableViewCell") as? RepTableViewCell else {
            return UITableViewCell()
        }
        
        guard let repDict = arrayForRepInfo.object(at: indexPath.row) as? [String:Any],
            let nameString = repDict["name"],
            let partyString = repDict["party"],
            let stateString = repDict["state"],
            let phoneString = repDict["phone"],
            let districtString = repDict["district"]
            else {
                showFailAlert(title: "Error Showing Reps", message: "Please try again later.")
                return cell
        }
        
        // Update properties on tableViewCell to reflect rep info
        cell.repCellTitle.text = "\(partyString)   \(nameString)"
        cell.repCellSubtitle.text = "\(stateString)  \(districtString)  \(phoneString)"
        cell.repCellImage.image = UIImage(named:"PhoneIcon")
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        // Call phone number of rep
        
        guard let repDict = arrayForRepInfo.object(at: indexPath.row) as? [String:Any],
            let phoneCallString = repDict["phone"]
            else {
                showFailAlert(title: "Error Showing Reps", message: "Please try again later.")
                return
        }
        
        if let url = URL(string: "tel://\(phoneCallString)") {
            if (UIApplication.shared.canOpenURL(url)) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                //Show alert if on the simulator or a device with no phone
                
                let refreshAlert = UIAlertController(title: "Not Able To Make Call", message: "Device does not support phone calls.", preferredStyle: UIAlertControllerStyle.alert)
                
                refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
                    refreshAlert.dismiss(animated: true, completion: nil)
                    
                }))
                present(refreshAlert, animated: true, completion: nil)
                
            }
            
        }
    }
}

// UITableView DataSource and Delegate
extension CallViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        print("locations = \(locValue.latitude) \(locValue.longitude)")
    }
    
    func populateZipField() {
        
        //finding address given the coordinates
        arrayForRepInfo = []
        tableView.reloadData()
        
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        
        guard let location = locationManager.location else {
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
            showFailAlert(title: "Location Fail", message: "Location data not available.")
            return
        }
        
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: {(placemarks, error) -> Void in
            
            if error != nil {
                if let error = error {
                    self.showFailAlert(title: "Reverse geocoder failed", message: error.localizedDescription)
                }
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                return
            }
            
            if placemarks!.count > 0 {
                let pm = placemarks![0]
                self.zipCodeField.text = pm.postalCode
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
            }
            else {
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
            }
        })
    }
    
}
