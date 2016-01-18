#import "PathExtra.h"
#include <sys/param.h>
#include <unistd.h>
#include <sys/xattr.h>

#ifndef AH_RETAIN
#if __has_feature(objc_arc)
#define AH_RETAIN(x) x
#define AH_RELEASE(x)
#define AH_AUTORELEASE(x) x
#define AH_SUPER_DEALLOC
#else
#define __AH_WEAK
#define AH_WEAK assign
#define AH_RETAIN(x) [x retain]
#define AH_RELEASE(x) [x release]
#define AH_AUTORELEASE(x) [x autorelease]
#define AH_SUPER_DEALLOC [super dealloc]
#endif
#endif

@implementation NSURL (PathExtra)
- (NSDictionary *)infoResolvingAliasFile
{
    // For compatibility. Use resolveAliasFileIsStale:(BOOL *)isStale error:(NSError **)error
    NSError *error = nil;
    NSDictionary *dict = [self resourceValuesForKeys:@[NSURLIsAliasFileKey, NSURLIsDirectoryKey]
                                               error:&error];
    if (error) {
        NSLog(@"Error at resourceValuesForKeys in infoResolvingAliasFile : %@", error);
        return nil;
    }
    
    NSURL *url = self;
    if ([dict[NSURLIsAliasFileKey] boolValue]) {
        NSData *bmdata = [NSURL bookmarkDataWithContentsOfURL:self error:&error];
        if (error) {
            NSLog(@"Error at bookmarkDataWithContentsOfURL in infoResolvingAliasFile : %@", error);
            goto bail;
        }
        BOOL is_stale = NO;
        url = [NSURL URLByResolvingBookmarkData:bmdata options:0 relativeToURL:NULL
                                   bookmarkDataIsStale:&is_stale error:&error];
        if (error) {
            NSLog(@"Error at URLByResolvingBookmarkData in infoResolvingAliasFile : %@", error);
        }
    }
bail:
	return @{@"ResolvedURL": url, @"IsDirectory": dict[NSURLIsDirectoryKey],
        @"WasAliased":dict[NSURLIsAliasFileKey]};
}

- (NSURL *)resolveAliasFileIsStale:(BOOL *)isStale error:(NSError **)error;
{
    NSNumber *is_alias = nil;
    if (![self getResourceValue:&is_alias forKey:NSURLIsAliasFileKey error:error]) {
        return nil;
    }
    if (![is_alias boolValue]) return self;
    
    NSData *bmdata = [NSURL bookmarkDataWithContentsOfURL:self error:error];
    if (*error) {
        return nil;
    }

    NSURL *url = [NSURL URLByResolvingBookmarkData:bmdata options:0 relativeToURL:NULL
                               bookmarkDataIsStale:isStale error:error];
    if (*error) {
        return nil;
    }
    return url;
}

- (BOOL)isVisible
{
    NSError *error = nil;
    NSNumber *is_hidden = nil;
    if (![self getResourceValue:&is_hidden forKey:NSURLIsHiddenKey error:&error]) {
        NSLog(@"error at getResourceValue in isVisible : %@", error);
        return NO;
    }
    return ![is_hidden boolValue];
}

- (BOOL)isFolder
{
    NSError *err = nil;
    NSNumber *result = nil;
    
    if (![self getResourceValue:&result
                         forKey:NSURLIsDirectoryKey error:&err]) {
        NSLog(@"error in isFolder : %@", err);
        return NO;
    }
    return [result boolValue];
}
@end

@implementation NSString (PathExtra)

- (NSDictionary *)infoResolvingAliasFile
{
	NSURL *url = [NSURL fileURLWithPath:self];
	NSDictionary *dict = [url infoResolvingAliasFile];
	if (dict == nil) return nil;
	
	NSString *resolved_path = self;
	if ([dict[@"WasAliased"] boolValue]) {
		resolved_path = [dict[@"ResolvedURL"] path];
	}
	
	NSMutableDictionary *result = [dict mutableCopy];
	result[@"ResolvedPath"] = resolved_path;
	return result;
}

- (BOOL)isVisible
{
    return [[NSURL fileURLWithPath:self] isVisible];
}

- (NSString *)uniqueName
{
	NSFileManager *file_manager = [NSFileManager defaultManager];
	if (![file_manager fileExistsAtPath:self]) return self;
	
	NSString *dir_path = [self stringByDeletingLastPathComponent];
	NSString *file_suffix = [self pathExtension];
	NSString *base_name = [[self lastPathComponent] stringByDeletingPathExtension];
	NSString *copy_suffix_format = NSLocalizedStringFromTable(@"%@ copy",
                                                              @"PathExtra_Localizable", 
                                                              @"The suffix for the dupulicated items");
	NSString *new_path = [dir_path stringByAppendingPathComponent:
					[NSString stringWithFormat:copy_suffix_format, base_name]];
	BOOL has_suffix = ([file_suffix length] > 0);
	
	if (has_suffix) 
		new_path = [new_path stringByAppendingPathExtension:file_suffix];
	
	int n = 1;
	NSString *new_name;
	copy_suffix_format = NSLocalizedStringFromTable(@"%@ copy%d",
                                                    @"PathExtra_Localizable", 
                                                    @"The suffix for the dupulicated items");
	while ([file_manager fileExistsAtPath:new_path]) {
		new_name = [NSString stringWithFormat:copy_suffix_format, base_name, n++ ];
		if (has_suffix) 
			new_name = [new_name stringByAppendingPathExtension:file_suffix];
			
		new_path = [dir_path stringByAppendingPathComponent:new_name];
	}
	return new_path;
}

- (NSString *)uniqueNameAtLocation:(NSString *)dirPath
{
	NSString *a_suffix = [self pathExtension];
	NSString *no_suffix_name = [self stringByDeletingPathExtension];
	return [no_suffix_name uniqueNameAtLocation:dirPath suffix:a_suffix];
}

- (NSString *)uniqueNameAtLocation:(NSString *)dirPath suffix:(NSString *)theSuffix
{
	BOOL has_suffix = [theSuffix length];
	NSString *newname = (has_suffix)? [self stringByAppendingPathExtension:theSuffix]: self;
	NSString *newpath = [dirPath stringByAppendingPathComponent:newname];
	NSFileManager *file_manager = [NSFileManager defaultManager];
	short i = 1;
	while ([file_manager fileExistsAtPath:newpath]){
		NSNumber *numberSuffix = @(i++);
		newname = [self stringByAppendingPathExtension:[numberSuffix stringValue]];
		if (has_suffix) 
			newname = [newname stringByAppendingPathExtension:theSuffix];
		newpath = [dirPath stringByAppendingPathComponent:newname];
	}
	return newname;	
}

- (NSString *)uniqueNameAtLocation:(NSString *)dirPath excepting:(NSArray *)exceptNames
{
	NSString *a_suffix = [self pathExtension];
	NSString *no_suffix_name = [self stringByDeletingPathExtension];
	return [no_suffix_name uniqueNameAtLocation:dirPath suffix:a_suffix excepting:exceptNames];
}

- (NSString *)uniqueNameAtLocation:(NSString *)dirPath suffix:(NSString *)theSuffix excepting:(NSArray *)exceptNames
{
	BOOL need_suffix = theSuffix && ([theSuffix length]);
	NSString *newname = need_suffix? [self stringByAppendingPathExtension:theSuffix]:self;
	NSString *newpath = [dirPath stringByAppendingPathComponent:newname];
	NSFileManager *file_manager = [NSFileManager defaultManager];
	short i = 1;
	while ([file_manager fileExistsAtPath:newpath] || [exceptNames containsObject:newname]){
		NSNumber *numberSuffix = @(i++);
		newname = [self stringByAppendingPathExtension:[numberSuffix stringValue]];
		if (need_suffix) newname = [newname stringByAppendingPathExtension:theSuffix];
		newpath = [dirPath stringByAppendingPathComponent:newname];
	}
	return newname;	
}

- (NSString *)cleanPath
{
	NSMutableString *newpath = [self mutableCopy];
	while(1) {
		if (![newpath replaceOccurrencesOfString:@"//" withString:@"" 
										 options:0 range:NSMakeRange(0, [newpath length])]) {
			break;
		}
	}
	
	if (([newpath length] > 1) && [newpath hasSuffix:@"/"]) {
		[newpath deleteCharactersInRange:NSMakeRange([newpath length]-1, 1)];
	}
	
	return newpath;
}

- (NSString *)relativePathWithBase:(NSString *)inBase {
	if (![inBase hasPrefix:@"/"])		{
		return nil	;
	}
	
	if (![self hasPrefix:@"/"]) {
		return nil;
	}
	
	NSArray *targetComps = [[self stringByStandardizingPath] pathComponents];
	
	NSString *selealizedBase = [inBase stringByStandardizingPath];
	NSArray *baseComps;
	if ([inBase hasSuffix:@"/"]) {
		selealizedBase = [selealizedBase stringByAppendingString:@"/"];
	}
	baseComps = [selealizedBase pathComponents];
	
	NSEnumerator *targetEnum = [targetComps objectEnumerator];
	NSEnumerator *baseEnum = [baseComps objectEnumerator];
	
	NSString *baseElement;
	NSString *targetElement = nil;

	BOOL hasRest = NO;
	BOOL hasTargetRest = YES;
	while( baseElement = [baseEnum nextObject]) {
		if (targetElement = [targetEnum nextObject]) {
			if (![baseElement isEqualToString:targetElement]) {
				hasRest = YES;
				break;
			}
		}
		else {
			hasTargetRest = NO;
			break;
		}
	}
	
	NSMutableArray *resultComps = [NSMutableArray array];
	if (hasRest) {
		while([baseEnum nextObject]) {
			[resultComps addObject:@".."];
		}
	}
	
	[resultComps addObject:targetElement];
	if (hasTargetRest) {
		while(targetElement = [targetEnum nextObject]) {
			[resultComps addObject:targetElement];
		}
	}
	
	return [resultComps componentsJoinedByString:@"/"];
}

- (BOOL)fileExists
{
	NSFileManager *file_manager = [NSFileManager defaultManager];
	return [file_manager fileExistsAtPath:self];
}

- (BOOL)isFolder
{
    NSError *error = nil;
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:self error:&error];
    if (error) {
        NSLog(@"Error in isFolder: %@", [error localizedDescription]);
        return NO;
    }
	return [[attr fileType] isEqualToString:NSFileTypeDirectory];
}

- (BOOL)isPackage
{
	return [[NSWorkspace sharedWorkspace] isFilePackageAtPath:self];
}

- (NSString *)displayName
{
	return [[NSFileManager defaultManager] displayNameAtPath:self];
}

static NSString *xattrError(const int err, const char *myPath)
{
    NSString *errMsg = nil;
    switch (err)
    {
        case ENOTSUP:
            errMsg = NSLocalizedString(@"File system does not support extended attributes or they are disabled.", @"Error description");
            break;
        case ERANGE:
            errMsg = NSLocalizedString(@"Buffer too small for attribute names.", @"Error description");
            break;
        case EPERM:
            errMsg = NSLocalizedString(@"This file system object does not support extended attributes.", @"Error description");
            break;
        case ENOTDIR:
            errMsg = NSLocalizedString(@"A component of the path is not a directory.", @"Error description");
            break;
        case ENAMETOOLONG:
            errMsg = NSLocalizedString(@"File name too long.", @"Error description");
            break;
        case EACCES:
            errMsg = NSLocalizedString(@"Search permission denied for this path.", @"Error description");
            break;
        case ELOOP:
            errMsg = NSLocalizedString(@"Too many symlinks encountered resolving path.", @"Error description");
            break;
        case EIO:
            errMsg = NSLocalizedString(@"I/O error occurred.", @"Error description");
            break;
        case EINVAL:
            errMsg = NSLocalizedString(@"Options not recognized.", @"Error description");
            break;
        case EEXIST:
            errMsg = NSLocalizedString(@"Options contained XATTR_CREATE but the named attribute exists.", @"Error description");
            break;
        case ENOATTR:
            errMsg = NSLocalizedString(@"The named attribute does not exist.", @"Error description");
            break;
        case EROFS:
            errMsg = NSLocalizedString(@"Read-only file system.  Unable to change attributes.", @"Error description");
            break;
        case EFAULT:
            errMsg = NSLocalizedString(@"Path or name points to an invalid address.", @"Error description");
            break;
        case E2BIG:
            errMsg = NSLocalizedString(@"The data size of the extended attribute is too large.", @"Error description");
            break;
        case ENOSPC:
            errMsg = NSLocalizedString(@"No space left on file system.", @"Error description");
            break;
        default:
            errMsg = NSLocalizedString(@"Unknown error occurred.", @"Error description");
            break;
    }
    return errMsg;
}

- (NSData *)extendedAttributeOfName:(NSString *)attrName transverseLink:(BOOL)resolveLink error:(NSError **)error
{
	const char *path = [self fileSystemRepresentation];
	const char *attr_name = [attrName UTF8String];
	
	int xopts = 0;
	if (!resolveLink) xopts = XATTR_NOFOLLOW;
	
	ssize_t bufsize = getxattr(path, attr_name, NULL, 0, 0, xopts);
	
	if (bufsize == -1) {
		int err = errno;
		NSString *errMsg = xattrError(err, path);
		if(error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err 
									userInfo:@{NSFilePathErrorKey: self, NSLocalizedDescriptionKey: errMsg}];
        return nil;
	}
	char *buffer = (char *)NSZoneMalloc(NSDefaultMallocZone(), sizeof(char)*bufsize);
	NSAssert(buffer != NULL, @"unable to allocate memory");
	ssize_t status = getxattr(path, attr_name, buffer, bufsize, 0, xopts);
	
	if(status == -1){
        int err = errno;
        NSString *errMsg = xattrError(err, path);
        if(error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err 
								userInfo:@{NSFilePathErrorKey: self, NSLocalizedDescriptionKey: errMsg}];
        NSZoneFree(NSDefaultMallocZone(), buffer);
        return nil;
    }
	
	 NSData *attribute = [[NSData alloc] initWithBytesNoCopy:buffer length:bufsize];
	 return AH_AUTORELEASE(attribute);
}

- (BOOL)setExtendAttribute:(NSData *)aValue forName:(NSString *)attrName
						transverseLink:(BOOL)resolveLink error:(NSError **)error
{
	const char *path = [self fileSystemRepresentation];
	const char *attr_name = [attrName UTF8String];
	const void *data = [aValue bytes];
	size_t datasize = [aValue length];
	
	int xopts = 0;
	if (!resolveLink) xopts = XATTR_NOFOLLOW;
	
	int status = setxattr(path, attr_name, data, datasize, 0, xopts);
	BOOL success;
	if(status == -1){
		int err = errno;
		NSString *errMsg = xattrError(err, path);
		if(error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err 
							userInfo:@{NSFilePathErrorKey: self, NSLocalizedDescriptionKey: errMsg}];
		success = NO;
	} else {
		success = YES;
	}
	return success;
}

- (NSString *)hfsPath
{
	CFURLRef an_url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)self, 
													kCFURLPOSIXPathStyle, false);
	CFStringRef a_path = CFURLCopyFileSystemPath(an_url, kCFURLHFSPathStyle);
	return (NSString *)CFBridgingRelease(a_path);
}

- (NSString *)posixPath
{
	CFURLRef an_url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)self, 
													kCFURLHFSPathStyle, false);
	CFStringRef a_path = CFURLCopyFileSystemPath(an_url, kCFURLPOSIXPathStyle);
	return (NSString *)CFBridgingRelease(a_path);
	
}

@end
