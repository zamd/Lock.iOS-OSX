//
//  A0APIClient.m
//  Pods
//
//  Created by Hernan Zalazar on 7/4/14.
//
//

#import "A0APIClient.h"

#import "A0Application.h"
#import "A0Strategy.h"

#import <AFNetworking/AFNetworking.h>
#import <libextobjc/EXTScope.h>

#define kClientIdKey @"AUTH0_CLIENT_ID"

@interface A0APIClient ()

@property (strong, nonatomic) NSString *clientId;
@property (strong, nonatomic) AFHTTPRequestOperationManager *manager;
@property (strong, nonatomic) A0Application *application;

@end

@implementation A0APIClient

- (instancetype)initWithClientId:(NSString *)clientId {
    self = [super init];
    if (self) {
        NSAssert(clientId, @"You must supply Auth0 Client Id.");
        _clientId = [clientId copy];
    }
    return self;
}

- (void)configureForApplication:(A0Application *)application {
    NSString *URLString = [NSString stringWithFormat:@"https://%@.auth0.com/api/", application.tenant.lowercaseString];
    NSURL *baseURL = [NSURL URLWithString:URLString];
    self.manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseURL];
    self.manager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    self.application = application;
}

- (void)fetchAppInfoWithSuccess:(A0APIClientSuccess)success
                                      failure:(A0APIClientError)failure {
    NSURL *connectionURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://s3.amazonaws.com/assets.auth0.com/client/%@.js", self.clientId]];
    NSURLRequest *request = [NSURLRequest requestWithURL:connectionURL];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            NSMutableString *json = [[NSMutableString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            NSRange range = [json rangeOfString:@"Auth0.setClient("];
            if (range.location != NSNotFound) {
                [json deleteCharactersInRange:range];
            }
            range = [json rangeOfString:@");"];
            if (range.location != NSNotFound) {
                [json deleteCharactersInRange:range];
            }
            NSError *error;
            NSDictionary *auth0AppInfo = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&error];
            A0Application *application = [[A0Application alloc] initWithJSONDictionary:auth0AppInfo];
            if (!error) {
                success(application);
            } else {
                if (failure) {
                    failure(error);
                }
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
    [operation start];
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
                  success:(A0APIClientSuccess)success
                  failure:(A0APIClientError)failure {
    A0Strategy *databaseStrategy = self.application.databaseStrategy;
    NSDictionary *params = @{
                             @"username": username,
                             @"password": password,
                             @"client_id": self.clientId,
                             @"connection": databaseStrategy.connection[@"name"],
                             @"grant_type": @"password",
                             @"scope": @"openid",
                             };
    @weakify(self);
    [self.manager POST:@"/oauth/ro" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *params = @{
                                 @"id_token": responseObject[@"id_token"],
                                 };
        @strongify(self);
        [self.manager POST:@"/tokeninfo" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if (success) {
                success(responseObject);
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if (failure) {
                failure(error);
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void)signUpWithUsername:(NSString *)username password:(NSString *)password success:(A0APIClientSuccess)success failure:(A0APIClientError)failure {
    A0Strategy *databaseStrategy = self.application.databaseStrategy;
    NSDictionary *params = @{
                             @"email": username,
                             @"password": password,
                             @"client_id": self.clientId,
                             @"connection": databaseStrategy.connection[@"name"],
                             @"tenant": self.application.tenant,
                             @"redirect_uri": self.application.callbackURL.absoluteString,
                             };
    @weakify(self);
    [self.manager POST:@"/dbconnections/signup" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        @strongify(self);
        [self loginWithUsername:username password:password success:success failure:failure];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

+ (instancetype)sharedClient {
    static A0APIClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *clientId = info[kClientIdKey];
        client = [[A0APIClient alloc] initWithClientId:clientId];
    });
    return client;
}

@end