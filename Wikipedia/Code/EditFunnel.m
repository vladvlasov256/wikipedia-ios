#import "EditFunnel.h"
#import <WMF/SessionSingleton.h>

static NSString *const kAppInstallIdKey = @"app_install_id";
static NSString *const kAnonKey = @"anon";
static NSString *const kTimestampKey = @"client_dt";
static NSString *const kWikidataDescriptionEdit = @"wikidataDescriptionEdit";

@implementation EditFunnel

- (id)initWithUserId:(int)userId {
    // https://meta.wikimedia.org/wiki/Schema:MobileWikiAppEdit
    self = [super initWithSchema:@"MobileWikiAppEdit" version:18115551];
    if (self) {
        self.editSessionToken = [self singleUseUUID];
    }
    self.userId = userId;
    return self;
}

- (NSDictionary *)preprocessData:(NSDictionary *)eventData {
    NSMutableDictionary *dict = [eventData mutableCopy];
    dict[@"session_token"] = self.editSessionToken;
    dict[kAnonKey] = self.isAnon;
    dict[kAppInstallIdKey] = self.appInstallID;
    dict[kTimestampKey] = self.timestamp;
    //dict[@"pageNS"] = @0; // @todo actually get the namespace...
    return [NSDictionary dictionaryWithDictionary:dict];
}

#pragma mark - EditFunnel methods

- (void)logStart {
    [self log:@{@"action": @"start"}];
}

- (void)logPreview {
    [self log:@{@"action": @"preview"}];
}

- (void)logEditSummaryTap:(NSString *)editSummaryTapped {
    [self log:@{@"action": @"editSummaryTap",
                @"editSummaryTapped": editSummaryTapped ? editSummaryTapped : @""}];
}

- (void)logSavedRevision:(int)revID {
    NSNumber *revIDNumber = [NSNumber numberWithInt:revID];
    [self log:@{@"action": @"saved",
                @"revID": (revIDNumber ? revIDNumber : @"")}];
}

- (void)logCaptchaShown {
    [self log:@{@"action": @"captchaShown"}];
}

- (void)logCaptchaFailure {
    [self log:@{@"action": @"captchaFailure"}];
}

- (void)logAbuseFilterWarning:(NSString *)name {
    [self log:@{@"action": @"abuseFilterWarning",
                @"abuseFilterName": (name ? name : @"")}];
}

- (void)logAbuseFilterError:(NSString *)name {
    [self log:@{@"action": @"abuseFilterError",
                @"abuseFilterName": (name ? name : @"")}];
}

- (void)logAbuseFilterWarningIgnore:(NSString *)name {
    [self log:@{@"action": @"abuseFilterWarningIgnore",
                @"abuseFilterName": (name ? name : @"")}];
}

- (void)logAbuseFilterWarningBack:(NSString *)name {
    [self log:@{@"action": @"abuseFilterWarningBack",
                @"abuseFilterName": (name ? name : @"")}];
}

- (void)logSaveAttempt {
    [self log:@{@"action": @"saveAttempt"}];
}

- (void)logError:(NSString *)code {
    [self log:@{@"action": @"error",
                @"errorText": (code ? code : @"")}];
}

-(void)logWikidataDescriptionEditingStart:(BOOL)isEditingExistingWikidataDescription {
    [self log:@{@"action": @"start",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingWikidataDescription]}];
}

-(void)logReadyToEditWikidataDescription:(BOOL)isEditingExistingWikidataDescription {
    [self log:@{@"action": @"ready",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingWikidataDescription]}];
}

-(void)logWikidataDescriptionEditSaveAttempt:(BOOL)isEditingExistingWikidataDescription {
    [self log:@{@"action": @"saveAttempt",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingWikidataDescription]}];
}

-(void)logWikidataDescriptionEditSaved:(BOOL)isEditingExistingWikidataDescription {
    [self log:@{@"action": @"saved",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingWikidataDescription]}];
}

-(NSString *)wikidataDescriptionType:(BOOL)isEditingExistingWikidataDescription {
    return isEditingExistingWikidataDescription ? @"existing" : @"new";
}

@end
