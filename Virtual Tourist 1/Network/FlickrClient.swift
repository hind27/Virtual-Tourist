//
//  FlickrClient.swift
//  Virtual Tourist 1
//
//  Created by hind on 2/10/19.
//  Copyright © 2019 hind. All rights reserved.
//

import Foundation
import UIKit

class Flickrclient {
    
    // MARK: - Properties
    var session = URLSession.shared
    var methodParameters : [String:AnyObject]
    var imgUrl : [String] = []
    var ImageTask : URLSessionTask!
    var PageTask : URLSessionTask!
    
    
    // MARK: Shared Instance
    class func shared() -> Flickrclient{
        struct Singleton {
            static var shared = Flickrclient()
        }
        return Singleton.shared
    }
    
    init() {
        // Get your Configuration Object
        let sessionConfiguration = URLSessionConfiguration.default
        // Set the Configuration on your session object
        session = URLSession(configuration: sessionConfiguration)
        methodParameters = [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            
            Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ] as [String:AnyObject]
        
    }
    
    
    
    func makeRequest(latitude : Double , longitude : Double , responseClosure: @escaping (_ page: Int , _ error: String?) -> Void){
        
        methodParameters[Constants.FlickrParameterKeys.BoundingBox] = bboxString(latitude: latitude,longitude: longitude) as AnyObject?
        
        print(methodParameters)
        
        // create session and request
        let request = URLRequest(url:flickrURLFromParameters( methodParameters))
        
        // create network request
        PageTask = session.dataTask(with: request) { (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(_ error: String) {
                print(error)
                responseClosure(0, error)
                
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                ///iphone not connected
                responseClosure(0, "check network connection")
                displayError("check network connection")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                responseClosure(0, error as? String)
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                responseClosure(0,"No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                
                displayError("Could not parse the data as JSON: '\(data)'")
                responseClosure(0, "Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (status != ok)? */
            guard let status = parsedResult[Constants.FlickrResponseKeys.Status] as? String, status == Constants.FlickrResponseValues.OKStatus else {
                
                displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                responseClosure(0, "Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Is "photos" key in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult)")
                responseClosure(0, "Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult)")
                return
            }
            
            /* GUARD: Is "pages" key in the photosDictionary? */
            guard let totalPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Pages)' in \(photosDictionary)")
                responseClosure(0, "Cannot find key '\(Constants.FlickrResponseKeys.Pages)' in \(photosDictionary)")
                
                return
            }
            responseClosure(totalPages, nil)
            
        }
        PageTask.resume()
    }
    
    
    // MARK: Helper for Creating a URL from Parameters
    private func flickrURLFromParameters(_ parameters: [String:AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
    
    private func bboxString(latitude : Double , longitude : Double) -> String {
        // ensure bbox is bounded by minimum and maximums
        
        let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
        let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
        let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
        let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
        return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
        
    }
    
    func displayImageFromFlickrBySearch(withPageNumber: Int , responseClosure: @escaping (_ imageUrlString:[ String] , _ error: String?) -> Void)  {
        
        // add the page to the method's parameters
        
        methodParameters[Constants.FlickrParameterKeys.Page] = withPageNumber as AnyObject?
        
        // create session and request
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        print (flickrURLFromParameters(methodParameters))
        
        // create network request
        ImageTask = session.dataTask(with: request) { (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(_ error: String) {
                print(error)
                responseClosure([""], error)
                
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error with your request")
              responseClosure([""], error as? String)
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                responseClosure([""], error as? String)
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                responseClosure([""], error as? String)
                displayError("No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                 displayError("Could not parse the data as JSON: '\(data)'")
                responseClosure([""], error as? String)
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                responseClosure([""], error as? String)
                return
            }
            
            /* GUARD: Is the "photos" key in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult)")
                responseClosure([""], error as? String)
                return
            }
            
            /* GUARD: Is the "photo" key in photosDictionary? */
            guard let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photosDictionary)")
                responseClosure([""], error as? String)
                return
            }
            
            if photosArray.count == 0 {
                displayError("No Photos Found. Search Again.")
                responseClosure([""], error as? String)
                return
            } else {
                for index in 0...photosArray.count-1 {
                    let photoDictionary = photosArray[index] as [String: AnyObject]
                    //url_n
                    /* GUARD: Does our photo have a key for 'url_n'? */
                    if let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL]
                        as? String   {
                        
                        self.imgUrl.append(imageUrlString)
                    // displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photoDictionary)")
                      //  responseClosure([""], error as? String)
                       // return
                    }
                   // self.imgUrl.append(imageUrlString)
                }
                
                responseClosure(self.imgUrl, nil)
                
            }
        }
        
        // start the task!
        ImageTask.resume()
        
    }
    func cancel(){
        if let Task = ImageTask
        {
            Task.cancel()
        }
        if let Task = PageTask
        {
            Task.cancel()
        }
    }
    
}
