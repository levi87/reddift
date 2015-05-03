//
//  RDTOAuth2Token.swift
//  reddift
//
//  Created by sonson on 2015/04/11.
//  Copyright (c) 2015年 sonson. All rights reserved.
//

import UIKit

let OAuth2TokenDidUpdate = "OAuth2TokenDidUpdate"

public class OAuth2Token : NSObject,NSCoding {
    static let baseURL = "https://www.reddit.com/api/v1"
    
    public var name = ""
    public var accessToken = ""
    public var tokenType = ""
    public var _expiresIn = 0
    public var expiresDate:NSTimeInterval = 0
    public var scope = ""
    public var refreshToken = ""
    
    // MARK:
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: "name")
        aCoder.encodeObject(accessToken, forKey: "accessToken")
        aCoder.encodeObject(tokenType, forKey: "tokenType")
        aCoder.encodeObject(_expiresIn, forKey: "_expiresIn")
        aCoder.encodeObject(expiresDate, forKey: "expiresDate")
        aCoder.encodeObject(scope, forKey: "scope")
        aCoder.encodeObject(refreshToken, forKey: "refreshToken")
    }
    
    public required init(coder aDecoder: NSCoder) {
        name = aDecoder.decodeObjectForKey("name") as! String
        accessToken = aDecoder.decodeObjectForKey("accessToken") as! String
        tokenType = aDecoder.decodeObjectForKey("tokenType") as! String
        _expiresIn = aDecoder.decodeObjectForKey("_expiresIn") as! Int
        expiresDate = aDecoder.decodeObjectForKey("expiresDate") as! NSTimeInterval
        scope = aDecoder.decodeObjectForKey("scope") as! String
        refreshToken = aDecoder.decodeObjectForKey("refreshToken") as! String
    }
    
    // MARK:
    
    /**
    Initialize OAuth2Token.
    
    :param: accessToken access token which is got from reddit.com.
    :param: tokenType token type which is got from reddit.com.
    :param: expiresIn time until token is expired.
    :param: scope scope has been authorized by reddit.com.
    :param: refreshToken refresh token which is got from reddit.com.
    */
    init(accessToken:String, tokenType:String, expiresIn:Int, scope:String, refreshToken:String) {
        super.init()
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.refreshToken = refreshToken
    }
    
    /**
    Create NSMutableURLRequest object to request getting an access token.
    
    :param: code The code which is obtained from OAuth2 redict URL at reddit.com.
    
    :returns: NSMutableURLRequest object to request your access token.
    */
    class func requestForOAuth(code:String) -> NSMutableURLRequest {
        var URL = NSURL(string: OAuth2Token.baseURL + "/access_token")!
        var request = NSMutableURLRequest(URL:URL)
        request.setRedditBasicAuthentication()
        var param = "grant_type=authorization_code&code=" + code + "&redirect_uri=" + Config.sharedInstance.redirectURI
        let data = param.dataUsingEncoding(NSUTF8StringEncoding)
        request.HTTPBody = data
        request.HTTPMethod = "POST"
        return request
    }
    
    /**
    Create NSMutableURLRequest object to request getting an access token.
    
    :param: code The code which is obtained from OAuth2 redict URL at reddit.com.
    
    :returns: NSMutableURLRequest object to request your access token.
    */
    class func tokenWithJSON(json:JSON) -> Result<OAuth2Token> {
        var token:OAuth2Token? = nil
        if let temp1 = json["access_token"] as? String,
            temp2 = json["token_type"] as? String,
            temp3 = json["expires_in"] as? Int,
            temp4 = json["scope"] as? String,
            temp5 = json["refresh_token"] as? String {
                token = OAuth2Token(accessToken:temp1, tokenType:temp2, expiresIn:temp3, scope:temp4, refreshToken:temp5)
        }
        return resultFromOptional(token, NSError(domain: "com.sonson.reddift", code: 1, userInfo: ["description":"Failed to parse t2 JSON in order to create OAuth2Token."]))
    }
    
    /**
    Update each property according to the new json object which is obtained from reddit.com.
    This method is used when your access token is refreshed by a refresh token.
    
    :param: json JSON object is parsed by NSJSONSerialization.JSONObjectWithData method.
    
    :returns: Result object. 
    */
    func updateWithJSON(json:JSON) -> Result<OAuth2Token> {
        let error = NSError(domain: "com.sonson.reddift", code: 1, userInfo: ["description":"Failed to parse t2 JSON in order to update OAuth2Token."])
        if  let temp1 = json["access_token"] as? String,
            temp2 = json["token_type"] as? String,
            temp3 = json["expires_in"] as? Int,
            temp4 = json["scope"] as? String {
                accessToken = temp1
                tokenType = temp2
                expiresIn = temp3
                scope = temp4
                return resultFromOptional(self, error)
        }
        return resultFromOptional(nil, error)
    }
    
    func requestForRefreshing() -> NSMutableURLRequest {
        var URL = NSURL(string: OAuth2Token.baseURL + "/access_token")!
        var request = NSMutableURLRequest(URL:URL)
        request.setRedditBasicAuthentication()
        var param = "grant_type=refresh_token&refresh_token=" + refreshToken
        let data = param.dataUsingEncoding(NSUTF8StringEncoding)
        request.HTTPBody = data
        request.HTTPMethod = "POST"
        return request
    }
    
    func requestForRevoking() -> NSMutableURLRequest {
        var URL = NSURL(string: OAuth2Token.baseURL + "/revoke_token")!
        var request = NSMutableURLRequest(URL:URL)
        request.setRedditBasicAuthentication()
        var param = "token=" + accessToken + "&token_type_hint=access_token"
        let data = param.dataUsingEncoding(NSUTF8StringEncoding)
        request.HTTPBody = data
        request.HTTPMethod = "POST"
        return request
    }
    
    // MARK:
    
    public var expiresIn:Int {
        set (newValue) {
            _expiresIn = newValue
            expiresDate = NSDate.timeIntervalSinceReferenceDate() + Double(_expiresIn)
        }
        get {
            return _expiresIn
        }
    }
    
    public func refresh(completion:(Result<OAuth2Token>)->Void) -> NSURLSessionDataTask {
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let task = session.dataTaskWithRequest(requestForRefreshing(), completionHandler: { (data:NSData!, response:NSURLResponse!, error:NSError!) -> Void in
            let responseResult = Result(error, Response(data: data, urlResponse: response))
            let result = responseResult >>> parseResponse >>> decodeJSON >>> self.updateWithJSON
            completion(result)
        })
        task.resume()
        return task
    }
    
    public func revoke(completion:(Result<JSON>)->Void) -> NSURLSessionDataTask {
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let task = session.dataTaskWithRequest(requestForRevoking(), completionHandler: { (data:NSData!, response:NSURLResponse!, error:NSError!) -> Void in
            let responseResult = Result(error, Response(data: data, urlResponse: response))
            let result = responseResult >>> parseResponse >>> decodeJSON
            completion(result)
        })
        task.resume()
        return task
    }
    
    public class func getOAuth2Token(code:String, completion:(Result<OAuth2Token>)->Void) -> NSURLSessionDataTask {
        let session:NSURLSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let task = session.dataTaskWithRequest(requestForOAuth(code), completionHandler: { (data:NSData!, response:NSURLResponse!, error:NSError!) -> Void in
            let responseResult = Result(error, Response(data: data, urlResponse: response))
            let result = responseResult >>> parseResponse >>> decodeJSON >>> OAuth2Token.tokenWithJSON
            completion(result)
        })
        task.resume()
        return task
    }
    
    public func getProfile(completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:"/api/v1/me", method:"GET", token:self)
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let task = session.dataTaskWithRequest(request, completionHandler: { (data:NSData!, response:NSURLResponse!, error:NSError!) -> Void in
            let responseResult = Result(error, Response(data: data, urlResponse: response))
            let result = responseResult >>> parseResponse >>> decodeJSON >>> parseThing_t2_JSON
            completion(result)
        })
        task.resume()
        return task
    }
}
