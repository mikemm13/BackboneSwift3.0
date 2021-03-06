//
//  Model+Conectivity.swift
//  BackboneSwift
//
//  Created by Fernando Canon on 27/10/16.
//  Copyright © 2016 Alphabit. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON


public typealias ResponseTuple =  (result:BaseObjectProtocol,metadata: ResponseMetadata)

public protocol ConnectivityProtocol {

 func synch<T:BaseObjectProtocol>(_ caller:T?,  modelURL:URLConvertible , method:HTTPMethod , options:HttpOptions?, onSuccess: @escaping (ResponseTuple)->Void , onError:@escaping (BackboneError)->Void)
    
    func processOptions(_ baseUrl:String , inOptions:HttpOptions?, complete: (_ options:HttpOptions? , _ url: URLComponents) -> Void)
    
    func processCache(usingOptions options : HttpOptions? , json :JSON , absoluteURL:URLConvertible ,andMethod method:HTTPMethod)
}

extension ConnectivityProtocol where Self : BaseObjectProtocol   {
 
    public func synch<T:BaseObjectProtocol>(_ caller:T? , modelURL:URLConvertible , method:HTTPMethod , options:HttpOptions? = nil, onSuccess: @escaping (ResponseTuple)->Void , onError:@escaping (BackboneError)->Void ){
        
        Alamofire.request(modelURL, method: method , parameters: options?.body, encoding: JSONEncoding.default, headers: options?.headers ).validate(statusCode: 200..<500).responseSwiftyJSON(completionHandler: { [weak caller] (dataResponse, jsonObject) in
            
            guard let weakSelf = caller else { return } // avoid retain cycle and Async callback crashes
            guard let response = dataResponse.response  else {
                onError(BackboneError.httpError(description: "No http status code"))
                return
            }
            
            let metadata = ResponseMetadata(httpResponse: response, fromCache: false)
            
            guard let json = jsonObject else {
                switch response.statusCode {
                case 200..<399:
                    onSuccess((weakSelf, metadata))
                default:
                    onError(.httpError(description: "\(response.statusCode)"))
                }
                return
            }
            
            switch response.statusCode {
            case 200..<299 :
                self.processCache(usingOptions: options, json: json , absoluteURL:modelURL , andMethod:method)
                weakSelf.parse(json)
                onSuccess((weakSelf , metadata))
                
            case 400..<499:
                let errorDictionary = json.dictionaryObject as! [String : AnyObject]
                onError(.errorWithJSON(parameters:errorDictionary))
            default:
                onError(BackboneError.errorWithJSON(parameters: ["description":"Could not manage the response sever" as AnyObject]))
            }
            })
    }

    
    public func processOptions(_ baseUrl:String , inOptions:HttpOptions?, complete: (_ options:HttpOptions? , _ url: URLComponents) -> Void) {
        var urlComponents = URLComponents(string:baseUrl)!
        if let query = inOptions?.query{
            urlComponents.query = query
        }
        if let path = inOptions?.relativePath  {
            if  urlComponents.path.characters.count != 0 {
                urlComponents.path = "\(urlComponents.path)/\(path)"
            }else {
                urlComponents.path = "/\(path)"
            }
        }
        complete(inOptions , urlComponents)
    }
    
    public func processCache(usingOptions options : HttpOptions? , json :JSON , absoluteURL:URLConvertible , andMethod method:HTTPMethod) {
        guard let opts = options ,  opts.useCache == true , cacheDelegate != nil else  {
             debugPrint("[ConnectivityProtocol where Self BaseObject]  Missing Parameter for cache ")
            return
        }
        do  {
            let key =  try absoluteURL.asURL().absoluteString
            switch method {
                case .get:
                    cacheDelegate?.requestCache.setObject(json.rawValue as AnyObject, forKey:key as NSString)
                default:
                    debugPrint("[ConnectivityProtocol where Self BaseObject] cache will only be use for http GET")
            }
       
        } catch {
                print("invalid key for cache")
        }
    }
}


