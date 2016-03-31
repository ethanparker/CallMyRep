//
//  ViewController.swift
//  WhoIsMyRepresentative
//
//  Created by Parker Play  on 3/14/16.
//  Copyright © 2016 Parker Planners. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, CLLocationManagerDelegate {
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
        self.searchButton.layer.cornerRadius = 20
        self.locationButton.layer.cornerRadius = 15
        self.tableView.tableFooterView = UIView()
        self.activityIndicator.hidden = true
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    // UITableView DataSource and Delegate
    func tableView(tableView:UITableView, numberOfRowsInSection section:Int) -> Int
    {
        return self.arrayForRepInfo.count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell:UITableViewCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "mycell")
        // Populate dictionary using array from API call
        let repDict = self.arrayForRepInfo.objectAtIndex(indexPath.row)
        let nameString = repDict["name"] as! String
        let partyString = repDict["party"] as! String
        let stateString = repDict["state"] as! String
        let phoneString = repDict["phone"] as! String
        let districtString = repDict["district"] as! String
        // Update properties on tableViewCell to reflect rep info
        cell.textLabel!.text = "\(partyString)   \(nameString)"
        cell.detailTextLabel!.text = "\(stateString)  \(districtString)  \(phoneString)"
        cell.imageView?.image = UIImage(named:"PhoneIcon")
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        // Call phone number of rep
        let repDict = self.arrayForRepInfo.objectAtIndex(indexPath.row)
        let phoneCallString = repDict["phone"] as! String
        if let url = NSURL(string: "tel://\(phoneCallString)") {
            if (UIApplication.sharedApplication().canOpenURL(url)) {
                UIApplication.sharedApplication().openURL(NSURL(string: "telprompt://\(phoneCallString)")!)
            } else {
                //Show alert if on the simulator or a device with no phone
              
                    let refreshAlert = UIAlertController(title: "Not Able To Make Call", message: "Device does not support phone calls.", preferredStyle: UIAlertControllerStyle.Alert)
                    
                    refreshAlert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: { (action: UIAlertAction!) in
                        refreshAlert .dismissViewControllerAnimated(true, completion: nil)
                        
                    }))
                    presentViewController(refreshAlert, animated: true, completion: nil)

            }
            
        }
    }
    
    // API call when search button is pressed, saves results into arrayForRepInfo
    @IBAction func searchRepApi(sender: AnyObject?) {
        // Dismiss keyboard
        self.view.endEditing(true)
        // Clear table view data
        self.arrayForRepInfo = []
        self.tableView.reloadData()
        // Check to see that the zip input is 5 digits
        let zipCodeString = self.zipCodeField.text
        if NSString(string: zipCodeString!).length < 5 || NSString(string: zipCodeString!).length > 6 {
            self.showWrongZipCodeAlert()
        } else {
            self.activityIndicator.startAnimating()
            self.activityIndicator.hidden = false
            self.apiCallForReps()
        }
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        print("locations = \(locValue.latitude) \(locValue.longitude)")
    }
    
    @IBAction func getZipFromLocatoin(sender: AnyObject) {
        //finding address given the coordinates
        
        self.arrayForRepInfo = []
        self.tableView.reloadData()
        
        self.activityIndicator.startAnimating()
        self.activityIndicator.hidden = false
        
        CLGeocoder().reverseGeocodeLocation(self.locationManager.location!, completionHandler: {(placemarks, error) -> Void in
            
            if error != nil {
                print("Reverse geocoder failed with error" + error!.localizedDescription)
                self.activityIndicator.stopAnimating()
                self.activityIndicator.hidden = true
                return
            }
            
            if placemarks!.count > 0 {
                let pm = placemarks![0]
                
                print(pm.postalCode!) //prints zip code
                self.zipCodeField.text = pm.postalCode
                self.activityIndicator.stopAnimating()
                self.activityIndicator.hidden = true
            }
            else {
                print("Problem with the data received from geocoder")
                self.activityIndicator.stopAnimating()
                self.activityIndicator.hidden = true
            }
        })
        
    }
    
    func apiCallForReps() {
        let zipCode = self.zipCodeField.text
        let urlString = NSString(format: "http://whoismyrepresentative.com/getall_mems.php?zip=%@&output=json", zipCode!)
        guard let url = NSURL(string: urlString as String) else { return }
        let request = NSURLRequest(URL: url)
        let session = NSURLSession(configuration: .defaultSessionConfiguration())
        let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
            guard let data = data else { return }
            do {
                let JSON = try NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions(rawValue: 0))
                guard let JSONDictionary :NSDictionary = JSON as? NSDictionary else {return}
                print("JSONDictionary from API call: \(JSONDictionary)")
                if let customerArray = JSONDictionary.valueForKey("results") as? NSArray {
                    self.arrayForRepInfo = customerArray
                }
            }
            catch let JSONError as NSError {
                print("\(JSONError)")
                
                dispatch_async(dispatch_get_main_queue(), {
                    self.activityIndicator.stopAnimating()
                    self.activityIndicator.hidden = true
                    self.showFailedZipCodeAttempt()
                })
                
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.tableView.reloadData()
                self.activityIndicator.stopAnimating()
                self.activityIndicator.hidden = true
            })
        }
        task.resume()
    }
    
    func showFailedZipCodeAttempt () {
        let alertTitle = "Zip Code Not Found"
        let alertMessage = "Please enter a valid US Zip Code."
        let alertOk = "Ok"
        
        let refreshAlert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.Alert)
        
        refreshAlert.addAction(UIAlertAction(title: alertOk, style: .Default, handler: { (action: UIAlertAction!) in
            refreshAlert .dismissViewControllerAnimated(true, completion: nil)
            
        }))
        presentViewController(refreshAlert, animated: true, completion: nil)
        
    }
    
    func showWrongZipCodeAlert () {
        let alertTitle = "Please Enter a Valid Zip Code"
        let alertMessage = "US Zip Codes are 5 digits."
        let alertOk = "Ok"
        
        let refreshAlert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.Alert)
        
        refreshAlert.addAction(UIAlertAction(title: alertOk, style: .Default, handler: { (action: UIAlertAction!) in
            refreshAlert .dismissViewControllerAnimated(true, completion: nil)
            
        }))
        presentViewController(refreshAlert, animated: true, completion: nil)
        
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        self.searchRepApi(nil)
        return true
    }
    
}

