//https://github.com/marcuswestin/WebViewProxy API
/*
 Proxy requests for a web views, easily and without mucking around with NSURLProtocol.
 
 Works on iOS and OSX.
 
 Responses to intercepted requests may be served either synchronously or asynchronously - this stands in contrast to the UIWebViewDelegate method -(NSCachedURLResponse *)cachedResponseForRequest:url:host:path:, which may only intercept requests and serve responses synchronously (making it impossible to e.g. proxy requests through to the network without blocking on the network request).
 
 If you like WebViewProxy you should also check out WebViewJavascriptBridge.
 */
#import <Foundation/Foundation.h>

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
#import <Cocoa/Cocoa.h>
#import <NSKit/NSKit.h>
#define WVPImageType NSImage
#define WVP_OSX
#else
#import <UIKit/UIKit.h>
#define WVPImageType UIImage
#endif

typedef void (^StopLoadingHandler)();
@interface WVPResponse : NSObject <NSURLConnectionDataDelegate>
@property (assign, nonatomic) NSURLCacheStoragePolicy cachePolicy;
@property (strong, nonatomic, nullable) NSURLRequest* request;

/*All registered handlers are given a WVPRespone* res. You respond to the request by calling methods on this object.
 There are 3 type of APIs for responding to a request
 High level API for responding with an image, text, html or json
 Low level API for responding with specific HTTP headers and NSData
 Piping API for passing data/errors from NSURLConnection through the WVPResponse
 */
#pragma mark High level API

/**
 Respond with an image (sent with Content-Type "image/png" by default, or "image/jpg" for requests that end in .jpg or .jpeg):
 @code
    [WebViewProxy handleRequestsWithHost:@"imageExample" path:@"GoogleLogo.png" handler:^(NSURLRequest* req, WVPResponse *res) {
        UIImage* image = [UIImage imageNamed:@"GoogleLogo.png"];
        [res respondWithImage:image];
    }];
 @endcode
 */
- (void)respondWithImage:(nullable WVPImageType*)image;

/**
 Respond with an image and the given mime type.
 @code
    [WebViewProxy handleRequestsWithHost:@"imageExample" handler:^(NSURLRequest* req, WVPResponse *res) {
        UIImage* image = [UIImage imageNamed:@"GoogleLogo.png"];
        [res respondWithImage:image mimeType:@"image/png"];
    }];
 @endcode
 */
- (void)respondWithImage:(nullable WVPImageType *)image mimeType:(nullable NSString *)mimeType;

/**
 Respond with a text response (sent with Content-Type "text/plain"):
 @code
    [WebViewProxy handleRequestsWithHost:@"textExample" handler:^(NSURLRequest* req, WVPResponse *res) {
        [res respondWithText:@"Hi!"];
    }];
 @endcode
 */
- (void)respondWithText:(nullable NSString *)text;

/**
 Respond with HTML (sent with Content-Type "text/html"):
 @code
    [WebViewProxy handleRequestsWithHost:@"htmlExample" handler:^(NSURLRequest* req, WVPResponse *res) {
        [res respondWithHTML:@"<div class='notification'>Hi!</div>"];
    }];
 @endcode
 */
- (void)respondWithHTML:(nullable NSString *)html;

/**
 Respond with JSON (sent with Content-Type "application/json"):
 @code
    [WebViewProxy handleRequestsWithHost:@"textExample" handler:^(NSURLRequest* req, WVPResponse *res) {
        NSDictionary* jsonObject = [NSDictionary dictionaryWithObject:@"foo" forKey:@"bar"];
        [res respondWithJSON:jsonObject]; // sends '{ "bar":"foo" }'
    }];
 @endcode
 */
- (void)respondWithJSON:(nullable NSDictionary *)jsonObject;

/**
 A request handler may be told to "stop loading". This can happen e.g as a result of cancel: being called on the underlying NSURLRequest. You can get notified of this via the handleStopLoadingRequest: method on WVPResponse.
 
 This API can be used to e.g stop performing an expensive computation in your request handler.
 @code
    [WebViewProxy handleRequestsMatching:predicate handler:^(NSURLRequest* req, WVPResponse *res) {
        NSOperation* expensiveOperation = [self startExpensiveOperation];
        [res handleStopLoadingRequest:^{
            [expensiveOperation cancel]
        }];
    }];
 @endcode
 */
- (void)handleStopLoadingRequest:(nullable StopLoadingHandler)stopLoadingHandler;

#pragma mark Low level API

/**
 Set a response header before responding.
 @code
    [res setHeader:@"Content-Type" value:@"image/gif"];
    [res setHeader:@"Content-Type" value:@"audio/wav"];
    [res setHeader:@"Host" value:@"WebViewProxy"];
 @endcode
 */
- (void)setHeader:(nullable NSString *)headerName value:(nullable NSString *)headerValue;

/**
 Set multiple response headers before responding.
 @code
    [res setHeaders:@{ @"Content-Type":@"image/gif", @"Host":@"WebViewProxy" }];
 @endcode
 */
- (void)setHeaders:(nullable NSDictionary *)headers;

/**
 Respond with the given HTTP status code and text.
 @code
    [res respondWithStatusCode:400 text:@"Bad request"];
    [res respondWithStatusCode:404 text:@"Not found"];
 @endcode
 */
- (void)respondWithStatusCode:(NSInteger)statusCode text:(nullable NSString *)text;

/**
 Respond with the given data and mime type (the mime type gets sent as the HTTP header Content-Type).
 
 If mimeType is nil, WebWiewProxy attempts to infer it from the request URL path extension.
 @code
    NSString* greeting = @"Hi!";
    NSData* data = [greeting dataUsingEncoding:NSUTF8StringEncoding];
    [res respondWithData:data mimeType:@"text/plain"];
 @endcode
 */
- (void)respondWithData:(nullable NSData *)data mimeType:(nullable NSString *)mimeType;

/**
 Respond with the given data, mime type and HTTP status code (the mime type gets sent as the HTTP header Content-Type).
 
 If mimeType is nil, WebWiewProxy attempts to infer it from the request URL path extension.
 @code
    NSData* data = [@"<div>Item has been created</div>" dataUsingEncoding:NSUTF8StringEncoding];
    [res respondWithData:data mimeType:@"text/html" statusCode:201];
    [res respondWithData:nil mimeType:nil statusCode:304]; // HTTP status code 304 "Not modified"
    [res respondWithData:nil mimeType:nil statusCode:204]; // HTTP status code 204 "No Content"
 @endcode
 */
- (void)respondWithData:(nullable NSData *)data mimeType:(nullable NSString *)mimeType statusCode:(NSInteger)statusCode;

#pragma mark Pipe data API
//Pipe an NSURLResponse and its data into the WVPResponse. This makes it simple to e.g. proxy a request and its response through an NSURLConnection.
/**Pipe an NSURLResponse into the response.*/
- (void)pipeResponse:(nullable NSURLResponse *)response;

/**Pipe data into the response.*/
- (void)pipeData:(nullable NSData *)data;

/**Pipe an error into the response (e.g a network error).*/
- (void)pipeError:(nullable NSError *)error;

/**Finish a piped response.*/
- (void)pipeEnd;

#pragma mark Private methods
- (nullable id)_initWithRequest:(nullable NSURLRequest *)request protocol:(nullable NSURLProtocol *)protocol;
- (void)_stopLoading;
@end

// The actual WebViewProxy API itself
typedef void (^WVPHandler)(NSURLRequest* __nullable req, WVPResponse* __nullable res);
@protocol WebViewProxyDelegate <NSObject>

/**
 You can do some special treatments to your current request.

 In generally, you will deal with movie request such as letv ,iqiyi and so on.
 
 While if you have some asynchronous actions, this delegate may not suitable, you may want to
 @see
 @code 
    + (void)setupProxyHost:(nullable NSString *)proxyHost port:(nullable NSNumber *)proxyPort withScheme:(nullable NSString *)scheme completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;
 @endcode
 or other methods which using block.
 @param req current request.
 @param data the response data.
 @param response encapsulates the metadata associated with the response to a a URL load request in a manner independent of protocol and URL scheme.
 */
- (void)specialTreatmentWithRequest:(nullable NSURLRequest *)req data:(nullable NSData *)data response:(nullable NSURLResponse *)response;

@end
@interface WebViewProxy : NSObject
@property (strong, nullable) id <WebViewProxyDelegate> delegate;
+ (nullable WebViewProxy *)sharedInstance;
+ (nullable id<WebViewProxyDelegate>)delegate;
+ (void)removeAllHandlers;

/**
 Intercept all UIWebView requests with the given scheme.
 @code
    [WebViewProxy handleRequestsWithScheme:@"my_custom_scheme" handler:^(NSURLRequest* req, WVPResponse *res) {
        [res respondWithText:@"Hi!"];
    }];
 @endcode
 */
+ (void)handleRequestsWithScheme:(nullable NSString *)scheme handler:(nullable WVPHandler)handler;

/**
 Intercept all UIWebView requests with the given host.
 @code
    [WebViewProxy handleRequestsWithHost:@"foo" handler:^(NSURLRequest* req, WVPResponse *res) {
        [res respondWithText:@"Hi!"];
    }];
 @endcode
 */
+ (void)handleRequestsWithHost:(nullable NSString *)host handler:(nullable WVPHandler)handler;
+ (void)handleRequestsWithAbsoluteString:(nullable NSString *)absoluteString handler:(nullable WVPHandler)handler;
+ (void)handleRequestsWithRelativePath:(nullable NSString *)relativePath handler:(nullable WVPHandler)handler;
+ (void)handleRequestsWithScheme:(nullable NSString *)scheme host:(nullable NSString *)host handler:(nullable WVPHandler)handler;

/**
 Intercept all UIWebView requests matching the given host and URL path.
 @code
    [WebViewProxy handleRequestsWithHost:@"foo.com" path:@"/bar" handler:^(NSURLRequest* req, WVPResponse *res) {
        [res respondWithText:@"Hi!"];
    }];
 @endcode
 */
+ (void)handleRequestsWithHost:(nullable NSString *)host path:(nullable NSString *)path handler:(nullable WVPHandler)handler;

/**
 Intercept all UIWebView requests matching the given host and URL path prefix.
 For example, a handler registered with [WebViewProxy handleRequestsWithHost:@"foo.com" pathPrefix:@"/bar" handler:...] will intercept requests for http://foo.com/bar, https://foo.com/bar/cat?wee=yes, http://foo.com/bar/arbitrarily/long/subpath, etc.
 @code
    [WebViewProxy handleRequestsWithHost:@"foo.com" pathPrefix:@"/bar" handler:^(NSURLRequest* req, WVPResponse *res) {
        [res respondWithText:@"Hi!"];
    }];
 @endcode
 */
+ (void)handleRequestsWithHost:(nullable NSString *)host pathPrefix:(nullable NSString *)pathPrefix handler:(nullable WVPHandler)handler;

/**
 Intercept all UIWebView requests where the NSURL matches the given NSPredicate.
 @code
    [WebViewProxy handleRequestsMatching:[NSPredicate predicateWithFormat:@"absoluteString MATCHES[cd] '^http:'"] handler:^(NSURLRequest* req, WVPResponse *res) {
        [res respondWithText:@"Hi!"];
    }];
 
    [WebViewProxy handleRequestsMatching:[NSPredicate predicateWithFormat:@"host MATCHES[cd] '[foo|bar]'"]  handler:^(NSURLRequest* req, WVPResponse *res) {
        [res respondWithText:@"Hi!"];
    }];
 @endcode
 */
+ (void)handleRequestsMatching:(nullable NSPredicate*)predicate handler:(nullable WVPHandler)handler;

+ (BOOL)registerProxy;
/**unregister the proxy when no longer use it.*/
+ (void)unregisterProxy;

#pragma mark - Setup Proxy

/**
 Setup proxy with the given scheme.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 @param scheme the given scheme to intercept.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
            withScheme:(nullable NSString *)scheme;
/**
 Setup proxy with the given scheme.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 @param scheme the given scheme to intercept.
 @param completionHandler 
 The completion handler to call when the load request is complete. This handler is executed on the delegate queue.
 If you pass nil, only the session delegate methods are called when the task completes, making this method equivalent to the dataTaskWithRequest: method.
 This completion handler takes the following parameters:
 
 data
 
 The data returned by the server.
 
 response
 
 An object that provides response metadata, such as HTTP headers and status code. If you are making an HTTP or HTTPS request, the returned object is actually an NSHTTPURLResponse object.
 
 error
 
 An error object that indicates why the request failed, or nil if the request was successful.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
            withScheme:(nullable NSString *)scheme
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the special scheme `http`.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
    portWithSchemeHTTP:(nullable NSNumber *)proxyPort;
+ (void)setupProxyHost:(nullable NSString *)proxyHost
    portWithSchemeHTTP:(nullable NSNumber *)proxyPort
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the special scheme `https`.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
   portWithSchemeHTTPS:(nullable NSNumber *)proxyPort;
+ (void)setupProxyHost:(nullable NSString *)proxyHost
   portWithSchemeHTTPS:(nullable NSNumber *)proxyPort
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the special scheme `http` or `https`.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost portWithSchemeHTTPOrHTTPS:(nullable NSNumber *)proxyPort;
+ (void)setupProxyHost:(nullable NSString *)proxyHost portWithSchemeHTTPOrHTTPS:(nullable NSNumber *)proxyPort
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the given host.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 @param host the given host to intercept.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
              withHost:(nullable NSString *)host;
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
              withHost:(nullable NSString *)host
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the given absolute string.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 @param absoluteString the given absolute string to intercept.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
    withAbsoluteString:(nullable NSString *)absoluteString;
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
    withAbsoluteString:(nullable NSString *)absoluteString
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the given relative path.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 @param relativePath the given relative path to intercept.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
      withRelativePath:(nullable NSString *)relativePath;
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
      withRelativePath:(nullable NSString *)relativePath
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the given scheme.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 @param host the given host to intercept.
 @param path the given path to intercept.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
              withHost:(nullable NSString *)host
                  path:(nullable NSString *)path;
+ (void)setupProxyHost:(nullable nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
              withHost:(nullable nullable NSString *)host
                  path:(nullable nullable NSString *)path
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the given host and path prefix.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 @param host the given host to intercept.
 @param pathPrefix the given path prefix to intercept.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
              withHost:(nullable NSString *)host
            pathPrefix:(nullable NSString *)pathPrefix;
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
              withHost:(nullable NSString *)host
            pathPrefix:(nullable NSString *)pathPrefix
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;

/**
 Setup proxy with the given predicate.
 @param proxyHost proxy host.
 @param proxyPort proxy port.
 @param predicate the given predicate to intercept.
 */
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
              matching:(nullable NSPredicate*)predicate;
+ (void)setupProxyHost:(nullable NSString *)proxyHost
                  port:(nullable NSNumber *)proxyPort
              matching:(nullable NSPredicate*)predicate
     completionHandler:(void (^__nullable)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler;
@end
