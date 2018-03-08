//
//  ViewController.swift
//  WhoIsMyRepresentative
//
//  Created by Parker Play  on 3/14/16.
//  Copyright © 2016 Parker Planners. All rights reserved.
//

import UIKit
import CoreLocation

class MainViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, CLLocationManagerDelegate {
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var zipCodeField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var locationButton: UIButton!
    var arrayForRepInfo: NSArray = []
    var locationManager: CLLocationManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.zipCodeField.delegate = self
        self.searchButton.layer.cornerRadius = searchButton.frame.size.height/2
        self.locationButton.layer.cornerRadius = locationButton.frame.size.height/2
        self.tableView.tableFooterView = UIView()
        self.activityIndicator.isHidden = true
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // UITableView DataSource and Delegate
    func tableView(_ tableView:UITableView, numberOfRowsInSection section:Int) -> Int
    {
        return self.arrayForRepInfo.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: "mycell")
        // Populate dictionary using array from API call
        
        guard let repDict = self.arrayForRepInfo.object(at: indexPath.row) as? [String:Any],
            let nameString = repDict["name"],
            let partyString = repDict["party"],
            let stateString = repDict["state"],
            let phoneString = repDict["phone"],
            let districtString = repDict["district"]
            else {
                print("Error populating values from json")
                return cell
        }
        
        // Update properties on tableViewCell to reflect rep info
        cell.textLabel!.text = "\(partyString)   \(nameString)"
        cell.detailTextLabel!.text = "\(stateString)  \(districtString)  \(phoneString)"
        cell.imageView?.image = UIImage(named:"PhoneIcon")
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        // Call phone number of rep
        
        guard let repDict = self.arrayForRepInfo.object(at: indexPath.row) as? [String:Any],
            let phoneCallString = repDict["phone"]
            else {
                print("Error populating values from json")
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
    
    @IBAction func searchRepApi(_ sender: Any) {
        // Dismiss keyboard
        self.view.endEditing(true)
        // Clear table view data
        self.arrayForRepInfo = []
        self.tableView.reloadData()
        // Check to see that the zip input is 5 digits
        let zipCodeString = self.zipCodeField.text
        if let zipCount = zipCodeString?.count {
            if zipCount < 5 || zipCount > 6 {
                self.showWrongZipCodeAlert()
            } else {
                self.activityIndicator.startAnimating()
                self.activityIndicator.isHidden = false
                self.apiCallForReps()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        print("locations = \(locValue.latitude) \(locValue.longitude)")
    }
    
    @IBAction func getZipFromLocation(_ sender: Any) {
        //finding address given the coordinates
        
        self.arrayForRepInfo = []
        self.tableView.reloadData()
        
        self.activityIndicator.startAnimating()
        self.activityIndicator.isHidden = false
        
        guard let location = self.locationManager.location else {
            showLocationFailAlert()
            return
        }
        
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: {(placemarks, error) -> Void in
            
            if error != nil {
                print("Reverse geocoder failed with error" + error!.localizedDescription)
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                return
            }
            
            if placemarks!.count > 0 {
                let pm = placemarks![0]
                
                print(pm.postalCode!) //prints zip code
                self.zipCodeField.text = pm.postalCode
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
            }
            else {
                print("Problem with the data received from geocoder")
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
            }
        })
        
    }
    
    func apiCallForReps() {
        let zipCode = self.zipCodeField.text
        let urlString = NSString(format: "http://whoismyrepresentative.com/getall_mems.php?zip=%@&output=json", zipCode!)
        guard let url = NSURL(string: urlString as String) else { return }
        let request = NSURLRequest(url: url as URL)
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            guard let data = data else { return }
            do {
                let JSON = try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions(rawValue: 0))
                guard let JSONDictionary :NSDictionary = JSON as? NSDictionary else {return}
                print("JSONDictionary from API call: \(JSONDictionary)")
                if let customerArray = JSONDictionary.value(forKey: "results") as? NSArray {
                    self.arrayForRepInfo = customerArray
                }
            }
            catch let JSONError as NSError {
                print("\(JSONError)")
                
                DispatchQueue.main.sync(execute: {
                    self.activityIndicator.stopAnimating()
                    self.activityIndicator.isHidden = true
                    self.showFailedZipCodeAttempt()
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
    
    func showLocationFailAlert() {
        let alertTitle = "Location Fail"
        let alertMessage = "Allow permission for location"
        let alertOk = "Ok"
        
        let refreshAlert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
        
        refreshAlert.addAction(UIAlertAction(title: alertOk, style: .default, handler: { (action: UIAlertAction!) in
            refreshAlert .dismiss(animated: true, completion: nil)
            
        }))
        present(refreshAlert, animated: true, completion: nil)
        
    }
    
    func showFailedZipCodeAttempt() {
        let alertTitle = "Zip Code Not Found"
        let alertMessage = "Please enter a valid US Zip Code."
        let alertOk = "Ok"
        
        let refreshAlert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
        
        refreshAlert.addAction(UIAlertAction(title: alertOk, style: .default, handler: { (action: UIAlertAction!) in
            refreshAlert .dismiss(animated: true, completion: nil)
            
        }))
        present(refreshAlert, animated: true, completion: nil)
        
    }
    
    func showWrongZipCodeAlert() {
        let alertTitle = "Please Enter a Valid Zip Code"
        let alertMessage = "US Zip Codes are 5 digits."
        let alertOk = "Ok"
        
        let refreshAlert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
        
        refreshAlert.addAction(UIAlertAction(title: alertOk, style: .default, handler: { (action: UIAlertAction!) in
            refreshAlert .dismiss(animated: true, completion: nil)
            
        }))
        present(refreshAlert, animated: true, completion: nil)
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        searchRepApi(self)
        return true
    }
    
}

