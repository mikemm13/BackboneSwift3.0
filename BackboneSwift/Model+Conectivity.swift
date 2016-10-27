//
//  Model+Conectivity.swift
//  BackboneSwift
//
//  Created by Fernando Canon on 27/10/16.
//  Copyright © 2016 Alphabit. All rights reserved.
//

import Foundation
import Alamofire

public protocol ConnectivityProtocol  {
    
 func synch<T:ModelProtocol>(_ caller:T?,  modelURL:URLConvertible , method:HTTPMethod , options:HttpOptions?, onSuccess: @escaping (ResponseTuple)->Void , onError:@escaping (BackboneError)->Void)
    
  func processOptions(_ baseUrl:String , inOptions:HttpOptions?, complete: (_ options:HttpOptions? , _ url: URLConvertible) -> Void)
}

extension ConnectivityProtocol where Self:Model {
 
    public func synch<T:ModelProtocol>(_ caller:T? , modelURL:URLConvertible , method:HTTPMethod , options:HttpOptions? = nil, onSuccess: @escaping (ResponseTuple)->Void , onError:@escaping (BackboneError)->Void ){
        
        Alamofire.request(modelURL, method: method , parameters: options?.body , headers: options?.headers ).validate(statusCode: 200..<500).responseSwiftyJSON(completionHandler: {  (dataResponse, jsonObject) in
            
            guard let weakSelf = caller else { return } // avoid retain cycle and Async callback crashes
            guard let httpStatus = dataResponse.response?.statusCode else {
                onError(BackboneError.httpError(description: "No http status code"))
                return
            }
            guard let json = jsonObject else {
                switch httpStatus {
                case 200..<399:
                    onSuccess((weakSelf, dataResponse.response))
                default:
                    onError(.httpError(description: "\(httpStatus)"))
                }
                return
            }
            
            switch httpStatus {
            case 200..<299 :
                weakSelf.parse(json)
                onSuccess((weakSelf , dataResponse.response))
                
            case 400..<499:
                let errorDictionary = json.dictionaryObject as! [String : AnyObject]
                onError(.errorWithJSON(parameters:errorDictionary))
            default:
                onError(BackboneError.errorWithJSON(parameters: ["description":"Could not manage the response sever" as AnyObject]))
            }
            })
    }

    
    public func processOptions(_ baseUrl:String , inOptions:HttpOptions?, complete: (_ options:HttpOptions? , _ url: URLConvertible) -> Void) {
        
        var urlComponents = URLComponents(string:baseUrl)!
        
        if let query = inOptions?.query{
            urlComponents.query = query
        }
        if let path = inOptions?.relativePath  {
            
            if  urlComponents.path.characters.count == 0 {
                urlComponents.path = "\(urlComponents.path)/\(path)"
            }else {
                urlComponents.path = "/\(path)"
            }
        }
        complete(inOptions , urlComponents)
    }
        
}

 
