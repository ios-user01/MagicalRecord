//
//  NSPersistentStore+MagicalRecord.m
//
//  Created by Saul Mora on 3/11/10.
//  Copyright 2010 Magical Panda Software, LLC All rights reserved.
//

#import "NSPersistentStore+MagicalRecord.h"
#import "NSError+MagicalRecordErrorHandling.h"
#import "MagicalRecordLogging.h"


NSString * const kMagicalRecordDefaultStoreFileName = @"CoreDataStore.sqlite";

@implementation NSPersistentStore (MagicalRecord)

+ (NSURL *) MR_defaultLocalStoreUrl;
{
    return [self MR_fileURLForStoreName:kMagicalRecordDefaultStoreFileName];
}

+ (NSURL *) MR_fileURLForStoreName:(NSString *)storeFileName;
{
    NSURL *storeURL = [self MR_fileURLForStoreNameIfExistsOnDisk:storeFileName];

    if (storeURL == nil)
    {
        NSString *storePath = [[self MRPrivate_applicationSupportDirectory] stringByAppendingPathComponent:storeFileName];
        storeURL = [NSURL fileURLWithPath:storePath];
    }

    return storeURL;
}

+ (NSURL *) MR_fileURLForStoreNameIfExistsOnDisk:(NSString *)storeFileName;
{
	NSArray *paths = [NSArray arrayWithObjects:[self MRPrivate_applicationDocumentsDirectory], [self MRPrivate_applicationSupportDirectory], nil];
    NSFileManager *fm = [[NSFileManager alloc] init];

    for (NSString *path in paths)
    {
        NSString *filepath = [path stringByAppendingPathComponent:storeFileName];

        if ([fm fileExistsAtPath:filepath])
        {
            return [NSURL fileURLWithPath:filepath];
        }
    }

    return nil;
}

+ (NSURL *) MR_cloudURLForUbiqutiousContainer:(NSString *)bucketName;
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSURL *cloudURL = nil;
    if ([fileManager respondsToSelector:@selector(URLForUbiquityContainerIdentifier:)])
    {
        cloudURL = [fileManager URLForUbiquityContainerIdentifier:bucketName];
    }

    return cloudURL;
}

- (BOOL) MR_isSqliteStore;
{
    return [[self type] isEqualToString:NSSQLiteStoreType];
}

- (BOOL) copyToURL:(NSURL *)destinationUrl error:(NSError **)error;
{
    if (![self MR_isSqliteStore])
    {
        MRLogWarn(@"NSPersistentStore [%@] is not a %@", self, NSSQLiteStoreType);
        return NO;
    }

    NSArray *storeUrls = [self MR_sqliteURLs];

    BOOL success = YES;
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    for (NSURL *storeUrl in storeUrls)
    {
        NSURL *copyToURL = [destinationUrl URLByDeletingPathExtension];
        copyToURL = [copyToURL URLByAppendingPathExtension:[storeUrl pathExtension]];
        success &= [fileManager copyItemAtURL:storeUrl toURL:copyToURL error:error];
    }
    return success;
}

- (NSArray *) MR_sqliteURLs;
{
    if (![self MR_isSqliteStore])
    {
        MRLogWarn(@"NSPersistentStore [%@] is not a %@", self, NSSQLiteStoreType);
        return nil;
    }

    NSURL *primaryStoreURL = [self URL];
    NSAssert([primaryStoreURL isFileURL], @"Store URL [%@] does not point to a resource on the local file system", primaryStoreURL);
    
    NSMutableArray *storeURLs = [NSMutableArray arrayWithObject:primaryStoreURL];
    NSArray *extensions = @[@"sqlite-wal", @"sqlite-shm"];

    for (NSString *extension in extensions)
    {
        NSURL *extensionURL = [primaryStoreURL URLByDeletingPathExtension];
        extensionURL = [extensionURL URLByAppendingPathExtension:extension];

        NSError *error;
        BOOL fileExists = [extensionURL checkResourceIsReachableAndReturnError:&error];
        if (fileExists)
        {
            [storeURLs addObject:extensionURL];
        }
        [[error MR_coreDataDescription] MR_logToConsole];
    }
    return [NSArray arrayWithArray:storeURLs];
}

#pragma mark - Remove Store File(s)

- (BOOL) MR_removePersistentStoreFiles;
{
    return [[self class] MR_removePersistentStoreFilesAtURL:self.URL];
}

+ (BOOL) MR_removePersistentStoreFilesAtURL:(NSURL*)url;
{
    NSCAssert([url isFileURL], @"URL must be a file URL");

    NSString *rawURL = [url absoluteString];
    NSURL *shmSidecar = [NSURL URLWithString:[rawURL stringByAppendingString:@"-shm"]];
    NSURL *walSidecar = [NSURL URLWithString:[rawURL stringByAppendingString:@"-wal"]];

    BOOL removeItemResult = YES;

    for (NSURL *toRemove in [NSArray arrayWithObjects:url, shmSidecar, walSidecar, nil])
    {
        removeItemResult = removeItemResult && [[NSFileManager defaultManager] removeItemAtURL:toRemove error:nil];
    }

    return removeItemResult;
}

#pragma mark - Private Methods

+ (NSString *) MRPrivate_directoryInUserDomain:(NSSearchPathDirectory)directory;
{
    return [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) firstObject];
}

+ (NSString *) MRPrivate_applicationDocumentsDirectory;
{
	return [self MRPrivate_directoryInUserDomain:NSDocumentDirectory];
}

+ (NSString *) MRPrivate_applicationSupportDirectory;
{
    NSString *applicationName = [[[NSBundle bundleForClass:[MagicalRecord class]] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    return [[self MRPrivate_directoryInUserDomain:NSApplicationSupportDirectory] stringByAppendingPathComponent:applicationName];
}

@end

@implementation NSPersistentStore (MagicalRecordDeprecated)

+ (NSURL *) MR_defaultURLForStoreName:(NSString *)storeFileName;
{
    return [self MR_fileURLForStoreName:storeFileName];
}

+ (NSURL *) MR_urlForStoreName:(NSString *)storeFileName;
{
    return [self MR_fileURLForStoreNameIfExistsOnDisk:storeFileName];
}

@end
