#include "WebViewProxy.h"

static NSMutableArray* requestMatchers;
static NSPredicate* webViewUserAgentTest;
static NSPredicate* webViewProxyLoopDetection;
static NSString *webViewProxyFlagKey = @"webViewProxyFlagKey";

// A request matcher, which matches a UIWebView request to a registered WebViewProxyHandler
@interface WVPRequestMatcher : NSObject
@property (strong,nonatomic) NSPredicate* predicate;
@property (copy) WVPHandler handler;
+ (WVPRequestMatcher*)matchWithPredicate:(NSPredicate*)predicate handler:(WVPHandler)handler;
@end
@implementation WVPRequestMatcher
@synthesize predicate=_predicate, handler=_handler;
+ (WVPRequestMatcher*)matchWithPredicate:(NSPredicate *)predicate handler:(WVPHandler)handler {
    WVPRequestMatcher* matcher = [[WVPRequestMatcher alloc] init];
    matcher.handler = handler;
    matcher.predicate = predicate;
    return matcher;
}
@end

// This is the proxy response object, through which we send responses
@implementation WVPResponse {
    NSURLRequest* _request;
    NSURLProtocol* _protocol;
    NSMutableDictionary* _headers;
    BOOL _stopped;
    StopLoadingHandler _stopLoadingHandler;
}
@synthesize cachePolicy=_cachePolicy, request=_request;
- (id)_initWithRequest:(NSURLRequest *)request protocol:(NSURLProtocol*)protocol {
    if (self = [super init]) {
        _request = request;
        _protocol = protocol;
        _headers = [NSMutableDictionary dictionary];
        _cachePolicy = NSURLCacheStorageNotAllowed;
    }
    return self;
}
- (void) _stopLoading {
    _stopped = YES;
    if (_stopLoadingHandler) {
        _stopLoadingHandler();
        _stopLoadingHandler = nil;
    }
}
// High level API
- (void)respondWithImage:(WVPImageType *)image {
    [self respondWithImage:image mimeType:nil];
}
- (void)respondWithImage:(WVPImageType *)image mimeType:(NSString *)mimeType {
    if (!mimeType) {
        NSString* extension = _protocol.request.URL.pathExtension;
        if ([extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"]) {
            mimeType = @"image/jpg";
        } else {
            if (![extension isEqualToString:@"png"]) {
                NSLog(@"WebViewProxy: responding with default mimetype image/png");
            }
            mimeType = @"image/png";
        }
    }
    [self _respondWithImage:image mimeType:mimeType];
}

- (void)respondWithJSON:(NSDictionary *)jsonObject {
    NSData* data = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:nil];
    [self respondWithData:data mimeType:@"application/json"];
}
- (void)respondWithText:(NSString *)text {
    NSData* data = [text dataUsingEncoding:NSUTF8StringEncoding];
    [self respondWithData:data mimeType:@"text/plain"];
}
- (void)respondWithHTML:(NSString *)html {
    NSData* data = [html dataUsingEncoding:NSUTF8StringEncoding];
    [self respondWithData:data mimeType:@"text/html"];
}
- (void)handleStopLoadingRequest:(StopLoadingHandler)handler {
    _stopLoadingHandler = handler;
}
// Low level API
- (void)setHeader:(NSString *)headerName value:(NSString *)headerValue {
    _headers[headerName] = headerValue;
}
- (void)setHeaders:(NSDictionary *)headers {
    for (NSString* headerName in headers) {
        [self setHeader:headerName value:headers[headerName]];
    }
}
- (void)respondWithData:(NSData *)data mimeType:(NSString *)mimeType {
    [self respondWithData:data mimeType:mimeType statusCode:200];
}
- (void)respondWithStatusCode:(NSInteger)statusCode text:(NSString *)text {
    NSData* data = [text dataUsingEncoding:NSUTF8StringEncoding];
    [self respondWithData:data mimeType:@"text/plain" statusCode:statusCode];
}

- (void)respondWithData:(NSData *)data mimeType:(NSString *)mimeType statusCode:(NSInteger)statusCode {
    if (_stopped) { return; }
    if (!_headers[@"Content-Type"]) {
        if (!mimeType) {
            mimeType = [self _mimeTypeOf:_protocol.request.URL.pathExtension];
        }
        if (mimeType) {
            _headers[@"Content-Type"] = mimeType;
        }
    }
    if (!_headers[@"Content-Length"]) {
        _headers[@"Content-Length"] = [self _contentLength:data];
    }
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:_protocol.request.URL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:_headers];
    [_protocol.client URLProtocol:_protocol didReceiveResponse:response cacheStoragePolicy:_cachePolicy];
    [_protocol.client URLProtocol:_protocol didLoadData:data];
    [_protocol.client URLProtocolDidFinishLoading:_protocol];
}
- (NSString*) _mimeTypeOf:(NSString*)pathExtension {
    static NSDictionary* mimeTypes = nil;
    if (mimeTypes == nil) {
        mimeTypes = @{
                    @"png":@"image/png",
                    @"jpg":@"image/jpg",
                    @"jpeg":@"image/jpg",
                    @"gif":@"image/gif",
                    @"tif":@"image/tiff",
                    @"tiff":@"image/tiff",
                    @"jpe":@"image/jpeg",
                    @"ras":@"image/x-cmu-raster",
                    @"pbm":@"image/x-portable-bitmap",
                    @"ppm":@"image/x-portable-pixmap",
                    @"xbm":@"image/x-xbitmap",
                    @"xwd":@"image/x-xwindowdump",
                    @"ief":@"image/ief",
                    @"pnm":@"image/x-portable-anymap",
                    @"pgm":@"image/x-portable-graymap",
                    @"rgb":@"image/x-rgb",
                    @"xpm":@"image/x-xpixmap",
                    @"woff":@"font/woff",
                    @"ttf":@"font/opentype",
                    @"html":@"text/html;charset=utf-8",
                    @"htm":@"text/html;charset=utf-8",
                    @"htl":@"text/html",
                    @"txt":@"text/plain",
                    @"c":@"text/plain",
                    @"cc":@"text/plain",
                    @"h":@"text/plain",
                    @"rtx":@"text/richtext",
                    @"etx":@"text/x-setext",
                    @"tsv":@"text/tab-separated-values",
                    @"jad":@"text/vnd.sun.j2me.app-descriptor",
//                    @"ts":@"text/texmacs",
                    @"m3u":@"audio/x-mpegurl",
                    @"ts":@"application/octet-stream",
                    @"m3u":@"application/octet-stream",
                    @"m3u8":@"application/octet-stream",
                    @"m4a":@"audio/mp4a-latm",
                    @"mp3":@"audio/mpeg",
                    @"amr":@"audio/amr",
                    @"wav":@"audio/wav",
                    @"pmd":@"audio/pmd",
                    @"au":@"audio/basic",
                    @"snd":@"audio/basic",
                    @"wma":@"audio/x-ms-wma",
                    @"aif":@"audio/x-aiff",
                    @"aiff":@"audio/x-aiff",
                    @"aifc":@"audio/x-aiff",
                    @"mid":@"audio/mid",
                    @"m3u":@"audio/x-mpegurl",
                    @"mp4":@"video/mp4",
                    @"mpeg":@"video/mpeg",
                    @"mpg":@"video/mpeg",
                    @"mpe":@"video/mpeg",
                    @"avi":@"video/x-msvideo",
                    @"rmvb":@"video/rmvb",
                    @"rm":@"video/rm",
                    @"wmv":@"video/x-ms-wmv",
                    @"mov":@"video/quicktime",
                    @"moov":@"video/quicktime",
                    @"qt":@"video/quicktime",
                    @"3gp":@"video/3gpp",
                    @"movie":@"video/x-sgi-movie",
//                    @"mkv":@"video/x-matroska",
                    @"mkv":@"MKV-application/octet-stream",
                    @"exe":@"application/ocelet-stream",
                    @"flv":@"application/octet-stream",
                    @"bin":@"application/octet-stream",
                    @"ini":@"application/octet-stream",
                    @"ogg":@"application/ogg",
                    @"pdf":@"application/pdf",
                    @"doc":@"application/msword",
                    @"rtf":@"application/rtf",
                    @"zip":@"application/zip",
                    @"js": @"application/javascript; charset=utf-8",
                    @"jar":@"application/java-archive",
                    @"pdb":@"application/ebook",
                    @"cab":@"application/vnd.smartpohone",
                    @"hme":@"application/vnd.smartphone.thm",
                    @"rng":@"application/vnd.nokia.ringing-tone",
                    @"sdt":@"application/vnd.sie.thm",
                    @"sis":@"application/vnd.symbian.install",
                    @"thm":@"application/vnd.eri.thm",
                    @"tsk":@"application/vnd.ppc.thm",
                    @"utz":@"application/vnd.uiq.thm",
                    @"umd":@"application/umd",
                    @"hqx":@"application/mac-binhex40",
                    @"oda":@"application/oda",
                    @"ai":@"application/postsrcipt",
                    @"eps":@"application/postsrcipt",
                    @"es":@"application/postsrcipt",
                    @"mif":@"application/x-mif",
                    @"csh":@"application/x-csh",
                    @"dvi":@"application/x-dvi",
                    @"hdf":@"application/x-hdf",
                    @"nc":@"application/x-netcdf",
                    @"cdf":@"application/x-netcdf",
                    @"latex":@"application/x-latex",
                    @"ts":@"application/x-troll-ts",
                    @"src":@"application/x-wais-source",
                    @"bcpio":@"application/x-bcpio",
                    @"cpio":@"application/x-cpio",
                    @"gtar":@"application/x-gtar",
                    @"shar":@"application/x-shar",
                    @"sv4cpio":@"application/x-sv4cpio",
                    @"sv4crc":@"application/x-sv4crc",
                    @"tar":@"application/x-tar",
                    @"ustar":@"application/x-ustar",
                    @"man":@"application/x-troff-man",
                    @"sh":@"application/x-sh",
                    @"tcl":@"application/x-tcl",
                    @"tex":@"application/x-tex",
                    @"texi":@"application/x-texinfo",
                    @"texinfo":@"application/x-texinfo",
                    @"t":@"application/x-troff",
                    @"tr":@"application/x-troff",
                    @"roff":@"application/x-troff",
                    @"shar":@"application/x-shar",
                    @"me":@"application/x-troll-me",
                    @"ts":@"application/x-troll-ts",
                    @"swf":@"application/x-shockwave-flash",
                    @"sisx":@"x-epoc/x-sisx-app"
                    };
    }
    return mimeTypes[pathExtension];
}
// Pipe API
- (void)pipeResponse:(NSURLResponse *)response {
    [self pipeResponse:response cachingAllowed:NO];
}
- (void)pipeResponse:(NSURLResponse *)response cachingAllowed:(BOOL)cachingAllowed {
    if (_stopped) { return; }
    NSURLCacheStoragePolicy cachePolicy = cachingAllowed ? NSURLCacheStorageAllowed : NSURLCacheStorageNotAllowed;
    [_protocol.client URLProtocol:_protocol didReceiveResponse:response cacheStoragePolicy:cachePolicy];
}
- (void)pipeData:(NSData *)data {
    if (_stopped) { return; }
    [_protocol.client URLProtocol:_protocol didLoadData:data];
}
- (void)pipeEnd {
    if (_stopped) { return; }
    [_protocol.client URLProtocolDidFinishLoading:_protocol];
}
- (void)pipeError:(NSError *)error {
    if (_stopped) { return; }
    [_protocol.client URLProtocol:_protocol didFailWithError:error];
}
// NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self pipeResponse:response];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self pipeData:data];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self pipeEnd];
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self pipeError:error];
}

#ifdef WVP_OSX
// OSX version
- (void)_respondWithImage:(NSImage*)image mimeType:(NSString*)mimeType {
    NSData* data = [image TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:data];
    if ([mimeType isEqualToString:@"image/jpg"]) {
        data = [imageRep
                representationUsingType:NSJPEGFileType
                properties:@{ NSImageCompressionFactor:[NSNumber numberWithFloat:1.0] }];
    } else if ([mimeType isEqualToString:@"image/png"]) {
        data = [imageRep
                representationUsingType:NSPNGFileType
                properties:@{ NSImageInterlaced:[NSNumber numberWithBool:NO] }];
    }
    [self respondWithData:data mimeType:mimeType];
}
- (NSString*)_contentLength:(NSData*)data {
    return [NSString stringWithFormat:@"%ld", data.length];
}
#else
// iOS Version
- (void)_respondWithImage:(UIImage*)image mimeType:(NSString*)mimeType {
    NSData* data;
    if ([mimeType isEqualToString:@"image/jpg"]) {
        data = UIImageJPEGRepresentation(image, 1.0);
    } else if ([mimeType isEqualToString:@"image/png"]) {
        data = UIImagePNGRepresentation(image);
    }
    [self respondWithData:data mimeType:mimeType];
}
- (NSString*)_contentLength:(NSData*)data {
    return [NSString stringWithFormat:@"%lu", (unsigned long)data.length];
}
#endif

@end

// The NSURLProtocol implementation that allows us to intercept requests.
@interface WebViewProxyURLProtocol : NSURLProtocol
@property (strong,nonatomic) WVPResponse* proxyResponse;
@property (strong,nonatomic) WVPRequestMatcher* requestMatcher;
+ (WVPRequestMatcher*)findRequestMatcher:(NSURL*)url;
@end
@implementation WebViewProxyURLProtocol {
    NSMutableURLRequest* _correctedRequest;
}
@synthesize proxyResponse=_proxyResponse, requestMatcher=_requestMatcher;
+ (WVPRequestMatcher *)findRequestMatcher:(NSURL *)url {
    for (WVPRequestMatcher* requestMatcher in requestMatchers) {
        if ([requestMatcher.predicate evaluateWithObject:url]) {
            return requestMatcher;
        }
    }
    return nil;
}
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString* userAgent = request.allHTTPHeaderFields[@"User-Agent"];
    if (userAgent && ![webViewUserAgentTest evaluateWithObject:userAgent]) {return NO; }
//    if ([webViewProxyLoopDetection evaluateWithObject:request.URL]) {return NO; }
    NSString* proxyFlag = request.allHTTPHeaderFields[webViewProxyFlagKey];
    if (proxyFlag)
    {
        return NO; // No longer intercept which has been intercepted.
    }
    return ([self findRequestMatcher:request.URL] != nil);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    // TODO: Implement this here, or expose it through WebViewProxyResponse?
    return NO;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client {
    if (self = [super initWithRequest:request cachedResponse:cachedResponse client:client]) {
        
        // TODO How to handle cachedResponse?
        _correctedRequest = request.mutableCopy;
//        NSString* correctedFragment=@"";
//        if (_correctedRequest.URL.fragment) {
//            correctedFragment = @"__webviewproxyreq__";
//        } else {
//            correctedFragment = @"#__webviewproxyreq__";
//        }
//        _correctedRequest.URL = [NSURL URLWithString:[request.URL.absoluteString stringByAppendingString:correctedFragment]];
        
        // The URL has been intercepted
        [_correctedRequest addValue:[@(YES) stringValue] forHTTPHeaderField:webViewProxyFlagKey];

        self.requestMatcher = [self.class findRequestMatcher:request.URL];
        self.proxyResponse = [[WVPResponse alloc] _initWithRequest:request protocol:self];
    }
    return self;
}
- (void)startLoading {
    self.requestMatcher.handler(_correctedRequest, self.proxyResponse);
}
- (void)stopLoading {
    _correctedRequest = nil;
    [self.proxyResponse _stopLoading];
    self.proxyResponse = nil;
}
@end


// This is the actual WebViewProxy API
@implementation WebViewProxy
+ (WebViewProxy *)sharedInstance
{
    static dispatch_once_t once;
    static WebViewProxy *sharedWebViewProxy;
    dispatch_once(&once, ^ {
        sharedWebViewProxy = [[self alloc] init];
    });
    return sharedWebViewProxy;
}

+ (id<WebViewProxyDelegate>)delegate
{
    return [self sharedInstance].delegate;
}

+ (void)load {
#if ! __has_feature(objc_arc)
    [NSException raise:@"ARC_Required" format:@"WebViewProxy requires Automatic Reference Counting (ARC) to function properly. Bailing."];
#endif
}
+ (void)initialize {
    [WebViewProxy removeAllHandlers];
    webViewUserAgentTest = [NSPredicate predicateWithFormat:@"self MATCHES '^Mozilla.*Mac OS X.*'"];
    webViewProxyLoopDetection = [NSPredicate predicateWithFormat:@"self.fragment ENDSWITH '__webviewproxyreq__'"];
    // e.g. "Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Mobile/10A403"
    [NSURLProtocol registerClass:[WebViewProxyURLProtocol class]];
}
+ (void)removeAllHandlers {
    requestMatchers = [NSMutableArray array];
}
+ (void)handleRequestsWithScheme:(NSString *)scheme handler:(WVPHandler)handler {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"scheme MATCHES[cd] %@", scheme];
    [self handleRequestsMatching:predicate handler:handler];
}
+ (void)handleRequestsWithHost:(NSString *)host handler:(WVPHandler)handler {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"host MATCHES[cd] %@", host];
    [self handleRequestsMatching:predicate handler:handler];
}
+ (void)handleRequestsWithAbsoluteString:(NSString *)absoluteString handler:(WVPHandler)handler {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"absoluteString MATCHES[cd] %@", absoluteString];
    [self handleRequestsMatching:predicate handler:handler];
}
+ (void)handleRequestsWithRelativePath:(NSString *)relativePath handler:(WVPHandler)handler {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"relativePath MATCHES[cd] %@", relativePath];
    [self handleRequestsMatching:predicate handler:handler];
}
+ (void)handleRequestsWithScheme:(NSString *)scheme host:(NSString *)host handler:(WVPHandler)handler {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"scheme MATCHES[cd] %@ AND host MATCHES[cd] %@",scheme, host];
    [self handleRequestsMatching:predicate handler:handler];
}
+ (void)handleRequestsWithHost:(NSString *)host path:(NSString *)path handler:(WVPHandler)handler {
    path = [self _normalizePath:path];
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"host MATCHES[cd] %@ AND path MATCHES[cd] %@", host, path];
    [self handleRequestsMatching:predicate handler:handler];
}
+ (void)handleRequestsWithHost:(NSString *)host pathPrefix:(NSString *)pathPrefix handler:(WVPHandler)handler {
    pathPrefix = [self _normalizePath:pathPrefix];
    NSString* pathPrefixRegex = [NSString stringWithFormat:@"^%@.*", pathPrefix];
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"host MATCHES[cd] %@ AND path MATCHES[cd] %@", host, pathPrefixRegex];
    [self handleRequestsMatching:predicate handler:handler];
}
+ (void)handleRequestsMatching:(NSPredicate*)predicate handler:(WVPHandler)handler {
    // Match on any property of NSURL, e.g. "scheme MATCHES 'http' AND host MATCHES 'www.google.com'"
    [requestMatchers addObject:[WVPRequestMatcher matchWithPredicate:predicate handler:handler]];
}
+ (NSString *)_normalizePath:(NSString *)path {
    if (![path hasPrefix:@"/"]) {
        // Paths always being with "/", so help out people who forget it
        path = [@"/" stringByAppendingString:path];
    }
    return path;
}

+ (BOOL)registerProxy
{
    return [NSURLProtocol registerClass:[WebViewProxyURLProtocol class]];
}

+ (void)unregisterProxy
{
    [NSURLProtocol unregisterClass:[WebViewProxyURLProtocol class]];
}

#pragma mark - Setup Proxy
+ (void)setupProxyWithProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort request:(NSURLRequest *)req response:(WVPResponse *)res
{
    res.cachePolicy = NSURLCacheStorageAllowed;//http.*[^\\.js]$
//    NSString *proxyHost = @"125.46.68.98";
//    NSNumber *proxyPort = @4128;
    NSDictionary *proxyDict = @{
                                @"HTTPEnable" : @1,
                                (NSString *)kCFStreamPropertyHTTPProxyHost : proxyHost,
                                (NSString *)kCFStreamPropertyHTTPProxyPort : proxyPort,
                                (NSString *)kCFProxyTypeHTTP : @"kCFProxyTypeHTTP",
                                
                                @"HTTPSEnable" : @1,
                                (NSString *)kCFStreamPropertyHTTPSProxyHost : proxyHost,
                                (NSString *)kCFStreamPropertyHTTPSProxyPort : proxyPort,
                                (NSString *)kCFProxyTypeHTTPS : @"kCFProxyTypeHTTPS",
                                
                                @"SOCKSEnable" : @1,
                                @"SOCKSProxy" : proxyHost,
                                @"SOCKSPort" : proxyPort,
                                (NSString *)kCFProxyTypeSOCKS : @"kCFProxyTypeSOCKS"
                                };
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.connectionProxyDictionary = proxyDict;
    
    // Create a NSURLSession with our proxy aware configuration
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    
    // Dispatch the request on our custom configured session
    NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        id<WebViewProxyDelegate> delegate = [WebViewProxy delegate] ;
        if (delegate && [delegate respondsToSelector:@selector(specialTreatmentWithRequest:data:response:)])
        {
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
                [delegate specialTreatmentWithRequest:req data:data response:response];
                [res respondWithData:data mimeType:response.MIMEType statusCode:((NSHTTPURLResponse*)response).statusCode];
                dispatch_semaphore_signal(sema);
            });
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }
        else
            [res respondWithData:data mimeType:response.MIMEType statusCode:((NSHTTPURLResponse*)response).statusCode];
    }];
    [task resume];
}

+ (void)setupProxyWithProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort request:(NSURLRequest *)req response:(WVPResponse *)res completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    res.cachePolicy = NSURLCacheStorageAllowed;//http.*[^\\.js]$
    //    NSString *proxyHost = @"125.46.68.98";
    //    NSNumber *proxyPort = @4128;
    NSDictionary *proxyDict = @{
                                @"HTTPEnable" : @1,
                                (NSString *)kCFStreamPropertyHTTPProxyHost : proxyHost,
                                (NSString *)kCFStreamPropertyHTTPProxyPort : proxyPort,
                                (NSString *)kCFProxyTypeHTTP : @"kCFProxyTypeHTTP",
                                
                                @"HTTPSEnable" : @1,
                                (NSString *)kCFStreamPropertyHTTPSProxyHost : proxyHost,
                                (NSString *)kCFStreamPropertyHTTPSProxyPort : proxyPort,
                                (NSString *)kCFProxyTypeHTTPS : @"kCFProxyTypeHTTPS",
                                
                                @"SOCKSEnable" : @1,
                                @"SOCKSProxy" : proxyHost,
                                @"SOCKSPort" : proxyPort,
                                (NSString *)kCFProxyTypeSOCKS : @"kCFProxyTypeSOCKS"
                                };
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.connectionProxyDictionary = proxyDict;
    
    // Create a NSURLSession with our proxy aware configuration
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    
    // Dispatch the request on our custom configured session
    NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
            if (completionHandler)
                completionHandler(data, response, error);
            [res respondWithData:data mimeType:response.MIMEType statusCode:((NSHTTPURLResponse*)response).statusCode];
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }];
    [task resume];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withScheme:(NSString *)scheme
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithScheme:scheme handler:^(NSURLRequest *req, WVPResponse *res){
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withScheme:(NSString *)scheme completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithScheme:scheme handler:^(NSURLRequest *req, WVPResponse *res){
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost portWithSchemeHTTP:(NSNumber *)proxyPort
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithScheme:@"http" handler:^(NSURLRequest *req, WVPResponse *res){
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost portWithSchemeHTTP:(NSNumber *)proxyPort completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithScheme:@"http" handler:^(NSURLRequest *req, WVPResponse *res){
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost portWithSchemeHTTPS:(NSNumber *)proxyPort
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithScheme:@"https" handler:^(NSURLRequest *req, WVPResponse *res){
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost portWithSchemeHTTPS:(NSNumber *)proxyPort completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithScheme:@"https" handler:^(NSURLRequest *req, WVPResponse *res){
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost portWithSchemeHTTPOrHTTPS:(NSNumber *)proxyPort
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithScheme:@"^https?$" handler:^(NSURLRequest *req, WVPResponse *res){
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost portWithSchemeHTTPOrHTTPS:(NSNumber *)proxyPort completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithScheme:@"^https?$" handler:^(NSURLRequest *req, WVPResponse *res){
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withHost:(NSString *)host
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithHost:host handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withHost:(NSString *)host completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithHost:host handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withAbsoluteString:(NSString *)absoluteString
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithAbsoluteString:absoluteString handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withAbsoluteString:(NSString *)absoluteString completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithAbsoluteString:absoluteString handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withRelativePath:(NSString *)relativePath
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithRelativePath:relativePath handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withRelativePath:(NSString *)relativePath completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithRelativePath:relativePath handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withHost:(NSString *)host path:(NSString *)path
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithHost:host path:path handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withHost:(NSString *)host path:(NSString *)path completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithHost:host path:path handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withHost:(NSString *)host pathPrefix:(NSString *)pathPrefix
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithHost:host pathPrefix:pathPrefix handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort withHost:(NSString *)host pathPrefix:(NSString *)pathPrefix completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsWithHost:host pathPrefix:pathPrefix handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort matching:(NSPredicate*)predicate
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsMatching:predicate handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res];
    }];
}

+ (void)setupProxyHost:(NSString *)proxyHost port:(NSNumber *)proxyPort matching:(NSPredicate*)predicate completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler
{
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    [WebViewProxy handleRequestsMatching:predicate handler:^(NSURLRequest *req, WVPResponse *res) {
        [WebViewProxy setupProxyWithProxyHost:proxyHost port:proxyPort request:req response:res completionHandler:completionHandler];
    }];
}
@end
