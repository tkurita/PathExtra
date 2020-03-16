#import <Cocoa/Cocoa.h>

@interface NSURL (PathExtra)

- (NSDictionary *)infoResolvingAliasFile;
- (NSURL *)resolveAliasFileIsStale:(BOOL *)isStale error:(NSError **)error;
- (BOOL)isVisible;
- (BOOL)isFolder;

@end

@interface NSString (PathExtra)

- (NSDictionary *)infoResolvingAliasFile;
- (BOOL)isVisible;
- (NSString *)cleanPath;
- (NSString *)relativePathWithBase:(NSString *)inBase;
- (NSString *)uniqueName;
- (NSString *)uniqueNameAtLocation:(NSString *)dirPath;
- (NSString *)uniqueNameAtLocation:(NSString *)dirPath suffix:(NSString *)theSuffix;
- (NSString *)uniqueNameAtLocation:(NSString *)dirPath excepting:(NSArray *)exceptNames;
- (NSString *)uniqueNameAtLocation:(NSString *)dirPath suffix:(NSString *)theSuffix excepting:(NSArray *)exceptNames;
- (BOOL)fileExists;
- (BOOL)isFolder;
- (BOOL)isPackage;
- (NSString *)displayName;

- (NSData *)extendedAttributeOfName:(NSString *)attrName 
						transverseLink:(BOOL)resolveLink error:(NSError **)error;
- (BOOL)setExtendAttribute:(NSData *)aValue forName:(NSString *)attrName
						transverseLink:(BOOL)resolveLink error:(NSError **)error;
#if useDeprecated //kCFURLPOSIXPathStyle is deprecated in 10.9
- (NSString *)hfsPath;
- (NSString *)posixPath;
#endif
- (NSURL *)fileURL;

@end
