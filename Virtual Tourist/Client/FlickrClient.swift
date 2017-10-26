//
//  FlickrClient.swift
//  Virtual Tourist
//

import Foundation

class FlickrClient {
    
    static let photosPerPage = 12
    static let maximumPhotos = 4000
    
    // shared session
    var session = URLSession.shared
    
    // MARK: download image from the given url string
    
    func downloadImage(urlString: String, completion: @escaping (_ result: Data?, _ error: NSError?) -> Void) {
        if let imageUrl = URL(string: urlString) {
            URLSession.shared.dataTask(with: imageUrl) { data, response, error in
                completion(data, error as NSError?)
                }.resume()
        }
    }
    
    // MARK: Flickr API
    
    // MARK: get a random image from the api for the given coordinates.
    
    func getFlickrImage(latitude: Double, longitude: Double, completion: @escaping (_ result: [String: AnyObject]?, _ error: NSError?) -> Void) {
        
        getFlickrImages(latitude: latitude, longitude: longitude, page: nil, completion: { (photosArray, error) in
            if let error = error {
                print(error)
                completion(nil, NSError(domain: "getFlickrImage parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse getFlickrImageString"]))
            } else {
                //select a random image from the array
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray!.count)))
                let photoDictionary = photosArray![randomPhotoIndex] as [String: AnyObject]
                
                completion(photoDictionary, nil)
            }
        })
    }
    
    // MARK: get random images from the api for the given coordinates. The amount of images is defined by the constant photosPerPage.
    
    func getFlickrImages(latitude: Double, longitude: Double, page: Int?, completion: @escaping (_ result:[[String: AnyObject]]?, _ error: NSError?) -> Void) {
        
        let parameters = [
            FlickrConstants.FlickrParameterKeys.Method: FlickrConstants.FlickrParameterValues.SearchMethod,
            FlickrConstants.FlickrParameterKeys.BoundingBox: bboxString(latitude: latitude, longitude: longitude),
            FlickrConstants.FlickrParameterKeys.SafeSearch: FlickrConstants.FlickrParameterValues.UseSafeSearch,
            FlickrConstants.FlickrParameterKeys.Extras: FlickrConstants.FlickrParameterValues.MediumURL,
            FlickrConstants.FlickrParameterKeys.Format: FlickrConstants.FlickrParameterValues.ResponseFormat,
            FlickrConstants.FlickrParameterKeys.NoJSONCallback: FlickrConstants.FlickrParameterValues.DisableJSONCallback,
            FlickrConstants.FlickrParameterKeys.PerPage: FlickrConstants.FlickrParameterValues.PerPage
        ]
        
        var methodParameters = parameters
        
        if let page = page {
            // add the page to the method's parameters
            methodParameters[FlickrConstants.FlickrParameterKeys.Page] = String(page)
        }
        
        /* 2. Make the request */
        _ = taskForGETMethod("", parameters: methodParameters as [String:AnyObject]) { (results, error) in
            if let error = error {
                print(error)
                completion(nil, error)
            } else {
                /* GUARD: Did Flickr return an error (stat != ok)? */
                guard let stat = results![FlickrConstants.FlickrResponseKeys.Status] as? String, stat == FlickrConstants.FlickrResponseValues.OKStatus else {
                    completion(nil, NSError(domain: "getFlickrImages parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Flickr API returned an error. See error code and message in \(String(describing: results))"]))
                    return
                }
                
                /* GUARD: Is "photos" key in our result? */
                guard let photosDictionary = results![FlickrConstants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                    completion(nil, NSError(domain: "getFlickrImages parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot find keys '\(FlickrConstants.FlickrResponseKeys.Photos)' in \(String(describing: results))"]))
                    return
                }
                
                /* GUARD: Is "pages" key in the photosDictionary? */
                guard let totalPages = photosDictionary[FlickrConstants.FlickrResponseKeys.Pages] as? Int else {
                    completion(nil, NSError(domain: "getFlickrImages parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot find key '\(FlickrConstants.FlickrResponseKeys.Pages)' in \(photosDictionary)"]))
                    return
                }
                
                if page == nil { // no page number was specified for the request, so pick a random page to query
                    let pageLimit = min(totalPages, self.calculateMaxPageNumber())
                    let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                    
                    //rerun the query, now for the random page
                    self.getFlickrImages(latitude: latitude, longitude: longitude, page: randomPage, completion: completion)
                } else { //parse the result
                    
                    /* GUARD: Is the "photo" key in photosDictionary? */
                    guard let photosArray = photosDictionary[FlickrConstants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                        completion(nil, NSError(domain: "getFlickrImages parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot find key '\(FlickrConstants.FlickrResponseKeys.Photo)' in \(photosDictionary)"]))
                        return
                    }
                    
                    if photosArray.count == 0 {
                        completion(nil, NSError(domain: "getFlickrImages parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "No Photos Found. Search Again."]))
                    } else {
                        completion(photosArray, nil)
                    }
                }
            }
        }
    }
    
    // MARK: GET
    
    func taskForGETMethod(_ method: String, parameters: [String:AnyObject], completionHandlerForGET: @escaping (_ result: [String: AnyObject]?, _ error: NSError?) -> Void) -> URLSessionDataTask {
        
        /* 1. Set the parameters */
        var parametersWithApiKey = parameters
        parametersWithApiKey[FlickrConstants.FlickrParameterKeys.APIKey] = FlickrConstants.FlickrParameterValues.APIKey as AnyObject?
        
        /* 2/3. Build the URL, Configure the request */
        let request = NSMutableURLRequest(url: flickrURLFromParameters(parametersWithApiKey))
        
        /* 4. Make the request */
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
            
            func sendError(_ error: String) {
                print(error)
                let userInfo = [NSLocalizedDescriptionKey : error]
                completionHandlerForGET(nil, NSError(domain: "taskForGETMethod", code: 1, userInfo: userInfo))
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                sendError("There was an error with your request: \(error!)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                sendError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                sendError("No data was returned by the request!")
                return
            }
            
            /* 5/6. Parse the data and use the data (happens in completion handler) */
            self.convertDataWithCompletionHandler(data, completionHandlerForConvertData: completionHandlerForGET)
        }
        
        /* 7. Start the request */
        task.resume()
        
        return task
    }
    
    // MARK: ensure bbox is bounded by minimum and maximums
    
    private func bboxString(latitude: Double, longitude: Double) -> String {
        let minimumLon = max(longitude - FlickrConstants.Flickr.SearchBBoxHalfWidth, FlickrConstants.Flickr.SearchLonRange.0)
        let minimumLat = max(latitude - FlickrConstants.Flickr.SearchBBoxHalfHeight, FlickrConstants.Flickr.SearchLatRange.0)
        let maximumLon = min(longitude + FlickrConstants.Flickr.SearchBBoxHalfWidth, FlickrConstants.Flickr.SearchLonRange.1)
        let maximumLat = min(latitude + FlickrConstants.Flickr.SearchBBoxHalfHeight, FlickrConstants.Flickr.SearchLatRange.1)
        return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
        
    }
    
    // MARK: Helpers
    
    // given raw JSON, return a usable Foundation object
    private func convertDataWithCompletionHandler(_ data: Data, completionHandlerForConvertData: (_ result: [String: AnyObject]?, _ error: NSError?) -> Void) {
        
        var parsedResult: AnyObject! = nil
        do {
            parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as AnyObject
        } catch {
            let userInfo = [NSLocalizedDescriptionKey : "Could not parse the data as JSON: '\(data)'"]
            completionHandlerForConvertData(nil, NSError(domain: "convertDataWithCompletionHandler", code: 1, userInfo: userInfo))
        }
        
        completionHandlerForConvertData(parsedResult as? [String: AnyObject], nil)
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String:AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = FlickrConstants.Flickr.APIScheme
        components.host = FlickrConstants.Flickr.APIHost
        components.path = FlickrConstants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
    
    // MARK: calculate the maximum page number for the request. The api returns at most roughly 4000 unique results. After that the same images will keep repeating in the results, so calculate the maximum page number
    private func calculateMaxPageNumber() -> Int {
        return FlickrClient.maximumPhotos / FlickrClient.photosPerPage
    }
    
    // MARK: Shared Instance
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
}
