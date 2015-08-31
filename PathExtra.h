#import <Cocoa/Cocoa.h>

@interface NSURL (PathExtra)

- (NSDictionary *)infoResolvingAliasFile;
- (NSURL *)resolveAliasFileIsStale:(BOOL *)isStale error:(NSError **)error;
- (BOOL)isVisible;

@end

@interface NSString (PathExtra)

- (NSDictionary *)infoResolvingAliasFile;
- (BOOL)isVisible;
- (BOOL)setStationeryFlag:(BOOL)newFlag;
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

- (NSString *)hfsPath;
- (NSString *)posixPath;

@end
