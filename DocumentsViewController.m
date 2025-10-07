#import "DocumentsViewController.h"

#if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#define HAS_UTTYPE 1
#else
#define HAS_UTTYPE 0
#endif

#if __has_include(<MobileCoreServices/MobileCoreServices.h>)
#import <MobileCoreServices/MobileCoreServices.h>
#define HAS_MOBILECORESERVICES 1
#else
#define HAS_MOBILECORESERVICES 0
#endif

static inline NSString *DocumentTypeItem(void) {
#if HAS_UTTYPE
  if (@available(iOS 14.0, *)) {
    UTType *t = UTTypeItem;
    return t.identifier;
  }
#endif
#if HAS_MOBILECORESERVICES
  return (__bridge NSString *)kUTTypeItem;
#else
  return @"public.item";
#endif
}

static inline NSString *DocumentTypeFolder(void) {
#if HAS_UTTYPE
  if (@available(iOS 14.0, *)) {
    UTType *t = UTTypeFolder;
    return t.identifier;
  }
#endif
#if HAS_MOBILECORESERVICES
  return (__bridge NSString *)kUTTypeFolder;
#else
  return @"public.folder";
#endif
}

@interface DocumentsViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic) dispatch_queue_t syncQueue;
@property(nonatomic, assign) BOOL cancelRequestedBacking;
@property(nonatomic, assign) BOOL exportingBacking;
@property(nonatomic, strong) NSURL *baseURLBacking;
@property(nonatomic, strong) UIAlertController *progressAlertBacking;
@property(nonatomic, strong) NSArray<NSURL *> *documentItemsBacking;
@end

@implementation DocumentsViewController

static const void *kSyncQueueSpecificKey = &kSyncQueueSpecificKey;

- (void)commonInitSyncQueue {
  if (self.syncQueue)
    return;
  self.syncQueue = dispatch_queue_create("DocumentsViewController.syncQueue", DISPATCH_QUEUE_CONCURRENT);
  dispatch_queue_set_specific(self.syncQueue, kSyncQueueSpecificKey, (void *)kSyncQueueSpecificKey, NULL);
  self.cancelRequestedBacking = NO;
  self.exportingBacking = NO;
  self.baseURLBacking = nil;
  self.progressAlertBacking = nil;
  self.documentItemsBacking = nil;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    [self commonInitSyncQueue];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self commonInitSyncQueue];
  }
  return self;
}

- (void)awakeFromNib {
  [super awakeFromNib];
  [self commonInitSyncQueue];
}

- (BOOL)isOnSyncQueue {
  if (!self.syncQueue)
    return NO;
  return dispatch_get_specific(kSyncQueueSpecificKey) == kSyncQueueSpecificKey;
}

- (void)setCancelRequested:(BOOL)cancelRequested {
  if ([self isOnSyncQueue]) {
    self.cancelRequestedBacking = cancelRequested;
    return;
  }
  dispatch_barrier_sync(self.syncQueue, ^{
    self.cancelRequestedBacking = cancelRequested;
  });
}

- (BOOL)cancelRequested {
  if ([self isOnSyncQueue]) {
    return self.cancelRequestedBacking;
  }
  __block BOOL value = NO;
  dispatch_sync(self.syncQueue, ^{
    value = self.cancelRequestedBacking;
  });
  return value;
}

- (void)setExporting:(BOOL)exporting {
  if ([self isOnSyncQueue]) {
    self.exportingBacking = exporting;
    return;
  }
  dispatch_barrier_sync(self.syncQueue, ^{
    self.exportingBacking = exporting;
  });
}

- (BOOL)exporting {
  if ([self isOnSyncQueue]) {
    return self.exportingBacking;
  }
  __block BOOL value = NO;
  dispatch_sync(self.syncQueue, ^{
    value = self.exportingBacking;
  });
  return value;
}

- (void)setBaseURL:(NSURL *)baseURL {
  if ([self isOnSyncQueue]) {
    self.baseURLBacking = baseURL;
    return;
  }
  dispatch_barrier_sync(self.syncQueue, ^{
    self.baseURLBacking = baseURL;
  });
}

- (NSURL *)baseURL {
  if ([self isOnSyncQueue]) {
    return self.baseURLBacking;
  }
  __block NSURL *value = nil;
  dispatch_sync(self.syncQueue, ^{
    value = self.baseURLBacking;
  });
  return value;
}

- (void)setProgressAlert:(UIAlertController *)progressAlert {
  if ([self isOnSyncQueue]) {
    self.progressAlertBacking = progressAlert;
    return;
  }
  dispatch_barrier_sync(self.syncQueue, ^{
    self.progressAlertBacking = progressAlert;
  });
}

- (UIAlertController *)progressAlert {
  if ([self isOnSyncQueue]) {
    return self.progressAlertBacking;
  }
  __block UIAlertController *value = nil;
  dispatch_sync(self.syncQueue, ^{
    value = self.progressAlertBacking;
  });
  return value;
}

- (void)setDocumentItems:(NSArray<NSURL *> *)documentItems {
  if ([self isOnSyncQueue]) {
    self.documentItemsBacking = [documentItems copy];
    return;
  }
  dispatch_barrier_sync(self.syncQueue, ^{
    self.documentItemsBacking = [documentItems copy];
  });
}

- (NSArray<NSURL *> *)documentItems {
  if ([self isOnSyncQueue]) {
    return self.documentItemsBacking;
  }
  __block NSArray<NSURL *> *value = nil;
  dispatch_sync(self.syncQueue, ^{
    value = self.documentItemsBacking;
  });
  return value;
}

+ (void)launchFrom:(UIViewController *)presenter {
  DocumentsViewController *vc = [[DocumentsViewController alloc] init];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  [presenter presentViewController:nav animated:YES completion:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = [UIColor whiteColor];

  self.navigationItem.leftBarButtonItem =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                    target:self
                                                    action:@selector(close)];

  UILabel *titleLabel = [[UILabel alloc] init];
  titleLabel.text = @"Documents Browser";
  if (@available(iOS 11.0, *)) {
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
  } else {
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
  }
  if (@available(iOS 10.0, *)) {
    titleLabel.adjustsFontForContentSizeCategory = YES;
  }
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.textAlignment = NSTextAlignmentCenter;

  UIButton *copyFileButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [copyFileButton setTitle:@"Copy File to App Documents" forState:UIControlStateNormal];
  [copyFileButton addTarget:self action:@selector(copyFile) forControlEvents:UIControlEventTouchUpInside];
  copyFileButton.translatesAutoresizingMaskIntoConstraints = NO;

  UIButton *copyFolderButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [copyFolderButton setTitle:@"Copy Folder to App Documents" forState:UIControlStateNormal];
  [copyFolderButton addTarget:self action:@selector(copyFolder) forControlEvents:UIControlEventTouchUpInside];
  copyFolderButton.translatesAutoresizingMaskIntoConstraints = NO;

  self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DocCell"];
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:titleLabel];
  [self.view addSubview:copyFileButton];
  [self.view addSubview:copyFolderButton];
  [self.view addSubview:self.tableView];

  UILayoutGuide *safe = nil;
  if (@available(iOS 11.0, *)) {
    safe = self.view.safeAreaLayoutGuide;
  } else {
    safe = self.view.layoutMarginsGuide;
  }
  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12.0],
    [titleLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],

    [copyFileButton.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
    [copyFileButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
    [copyFileButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],

    [copyFolderButton.topAnchor constraintEqualToAnchor:copyFileButton.bottomAnchor constant:8.0],
    [copyFolderButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
    [copyFolderButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],

    [self.tableView.topAnchor constraintEqualToAnchor:copyFolderButton.bottomAnchor constant:12.0],
    [self.tableView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
    [self.tableView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
    [self.tableView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor]
  ]];

  UILabel *tableHeader = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, self.view.bounds.size.width - 32, 44)];
  UIFont *base = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
  tableHeader.font = [UIFont boldSystemFontOfSize:base.pointSize];
  if (@available(iOS 10.0, *)) {
    tableHeader.adjustsFontForContentSizeCategory = YES;
  }
  tableHeader.text = @"App Documents:";
  tableHeader.textAlignment = NSTextAlignmentLeft;
  tableHeader.numberOfLines = 1;
  tableHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  self.tableView.tableHeaderView = tableHeader;

  [self cleanUpCopyingArtifacts];

  [self reloadDocuments];
}

- (void)close {
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Actions

- (void)copyFile {
  if (@available(iOS 14.0, *)) {
    [self presentDocumentPickerForOpeningContentTypes:@[ (id)UTTypeItem ] allowsMultiple:YES];
  } else {
    NSString *typeItem = DocumentTypeItem();
    [self presentDocumentPickerForDocumentTypes:@[ typeItem ] mode:UIDocumentPickerModeImport allowsMultiple:YES];
  }
}

- (void)copyFolder {
  if (@available(iOS 14.0, *)) {
    [self presentDocumentPickerForOpeningContentTypes:@[ (id)UTTypeFolder ] allowsMultiple:NO];
  } else {
    NSString *typeFolder = DocumentTypeFolder();
    [self presentDocumentPickerForDocumentTypes:@[ typeFolder ] mode:UIDocumentPickerModeOpen allowsMultiple:NO];
  }
}

- (void)presentDocumentPickerForOpeningContentTypes:(NSArray *)contentTypes allowsMultiple:(BOOL)allows {
  if (!contentTypes)
    return;
  if (@available(iOS 14.0, *)) {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes];
    picker.delegate = self;
    if (@available(iOS 11.0, *))
      picker.allowsMultipleSelection = allows;
    [self presentViewController:picker animated:YES completion:nil];
  } else {
    NSString *fallbackType = DocumentTypeItem();
    [self presentDocumentPickerForDocumentTypes:@[ fallbackType ]
                                           mode:UIDocumentPickerModeImport
                                 allowsMultiple:allows];
  }
}

- (void)presentDocumentPickerForDocumentTypes:(NSArray<NSString *> *)types
                                         mode:(UIDocumentPickerMode)mode
                               allowsMultiple:(BOOL)allows {
  UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types
                                                                                                  inMode:mode];
  picker.delegate = self;
  if (@available(iOS 11.0, *))
    picker.allowsMultipleSelection = allows;
  [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  if (self.exporting) {
    self.exporting = NO;
    return;
  }

  if (!urls || urls.count == 0) {
    [controller dismissViewControllerAnimated:YES completion:nil];
    return;
  }

  __weak typeof(self) weakSelf = self;
  [controller dismissViewControllerAnimated:YES
                                 completion:^{
                                   __strong typeof(self) s = weakSelf;
                                   if (!s)
                                     return;

                                   if (urls.count == 1) {
                                     NSURL *only = urls.firstObject;
                                     NSNumber *isDirNumber = nil;
                                     [only getResourceValue:&isDirNumber forKey:NSURLIsDirectoryKey error:NULL];
                                     BOOL isDir = [isDirNumber boolValue];
                                     if (isDir) {
                                       [s startImportFolderFromURL:only];
                                       return;
                                     }
                                   }

                                   [s startImportFilesFromURLs:urls];
                                 }];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
  if (self.exporting) {
    self.exporting = NO;
    return;
  }

  if (!url) {
    [controller dismissViewControllerAnimated:YES completion:nil];
    return;
  }

  __weak typeof(self) weakSelf = self;
  [controller dismissViewControllerAnimated:YES
                                 completion:^{
                                   __strong typeof(self) s = weakSelf;
                                   if (!s)
                                     return;
                                   NSNumber *isDirNumber = nil;
                                   [url getResourceValue:&isDirNumber forKey:NSURLIsDirectoryKey error:NULL];
                                   BOOL isDir = [isDirNumber boolValue];
                                   if (isDir) {
                                     [s startImportFolderFromURL:url];
                                   } else {
                                     [s startImportFilesFromURLs:@[ url ]];
                                   }
                                 }];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  if (self.exporting) {
    self.exporting = NO;
  }
  [self dismissProgress];
  [self reloadDocuments];
}

#pragma mark - Import (atomic, background, cancellable)

- (void)startImportFilesFromURLs:(NSArray<NSURL *> *)urls {
  if (!urls || urls.count == 0)
    return;
  {
    NSMutableSet *seen = [NSMutableSet set];
    for (NSURL *u in urls) {
      NSString *name =
          u.lastPathComponent ?: [NSString stringWithFormat:@"file_%f", [NSDate timeIntervalSinceReferenceDate]];
      if ([seen containsObject:name]) {
        [self showSimpleAlertWithTitle:@"Duplicate files"
                               message:@"Two or more selected files share the same "
                                       @"name. Rename files before importing."];
        return;
      }
      [seen addObject:name];
    }
  }

  NSURL *docsDir = [self appDocumentsDirectoryURL];

  [self showProgressWithMessage:@"Copying file(s)..."];

  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    __strong typeof(self) s = weakSelf;
    BOOL hadError = NO;

    for (NSURL *src in urls) {
      if (!s || s.cancelRequested)
        break;

      BOOL didStart = [src startAccessingSecurityScopedResource];
      if (!didStart) {
        hadError = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
          [s dismissProgress];
          [s showSimpleAlertWithTitle:@"Access denied" message:@"Unable to access selected file(s)."];
        });
        break;
      }

      @try {
        NSString *name =
            src.lastPathComponent ?: [NSString stringWithFormat:@"file_%f", [NSDate timeIntervalSinceReferenceDate]];
        NSURL *finalDest = [docsDir URLByAppendingPathComponent:name];
        NSURL *tempDest = [docsDir URLByAppendingPathComponent:[NSString stringWithFormat:@".%@.copying", name]];

        NSFileManager *fm = [[NSFileManager alloc] init];
        if ([fm fileExistsAtPath:finalDest.path] || [fm fileExistsAtPath:tempDest.path]) {
          hadError = YES;
          dispatch_async(dispatch_get_main_queue(), ^{
            [s dismissProgress];
            [s showFileExistsAlert:name];
          });
          break;
        }

        NSError *err = nil;
        BOOL ok = [s copyItemAtURL:src toDestinationURL:tempDest error:&err];
        if (!ok || err) {
          hadError = YES;
          [fm removeItemAtURL:tempDest error:NULL];
          dispatch_async(dispatch_get_main_queue(), ^{
            [s dismissProgress];
            [s showSimpleAlertWithTitle:@"Copy Failed"
                                message:err.localizedDescription ?: @"An unknown error occurred during copy."];
          });
          break;
        }

        if (!s.cancelRequested) {
          if (![fm moveItemAtURL:tempDest toURL:finalDest error:&err]) {
            hadError = YES;
            [fm removeItemAtURL:tempDest error:NULL];
          }
        } else {
          [fm removeItemAtURL:tempDest error:NULL];
        }
      } @finally {
        if (didStart)
          [src stopAccessingSecurityScopedResource];
      }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (!s)
        return;
      [s dismissProgress];
      [s reloadDocuments];
      if (s.cancelRequested) {
        [s showSimpleAlertWithTitle:@"Copy File(s)" message:@"Operation canceled."];
      } else if (!hadError) {
        [s showSimpleAlertWithTitle:@"Copy File(s)" message:@"File(s) copied successfully!"];
      }
      s.cancelRequested = NO;
    });
  });
}

- (void)startImportFolderFromURL:(NSURL *)url {
  if (!url)
    return;
  NSURL *docsDir = [self appDocumentsDirectoryURL];

  [self showProgressWithMessage:@"Copying folder..."];

  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    __strong typeof(self) s = weakSelf;
    BOOL hadError = NO;

    BOOL didStart = [url startAccessingSecurityScopedResource];
    if (!didStart) {
      hadError = YES;
      dispatch_async(dispatch_get_main_queue(), ^{
        [s dismissProgress];
        [s showSimpleAlertWithTitle:@"Access denied" message:@"Unable to access selected folder."];
      });
      return;
    }

    @try {
      NSString *folderName =
          url.lastPathComponent
              ?: [NSString stringWithFormat:@"ImportedFolder_%f", [NSDate timeIntervalSinceReferenceDate]];
      NSURL *finalDest = [docsDir URLByAppendingPathComponent:folderName];
      NSURL *tempDest = [docsDir URLByAppendingPathComponent:[NSString stringWithFormat:@".%@.copying", folderName]];

      NSFileManager *fm = [[NSFileManager alloc] init];
      if ([fm fileExistsAtPath:finalDest.path] || [fm fileExistsAtPath:tempDest.path]) {
        hadError = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
          [s dismissProgress];
          [s showFileExistsAlert:folderName];
        });
        return;
      }

      NSError *err = nil;

      BOOL ok = [s copyItemAtURL:url toDestinationURL:tempDest error:&err];
      if (!ok || err) {
        hadError = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
          [s dismissProgress];
          [s showSimpleAlertWithTitle:@"Copy Folder" message:err.localizedDescription ?: @"Folder copy failed."];
        });
        return;
      }

      if (!s.cancelRequested) {
        if (![fm moveItemAtURL:tempDest toURL:finalDest error:&err]) {
          hadError = YES;
          [fm removeItemAtURL:tempDest error:NULL];
        }
      } else {
        [fm removeItemAtURL:tempDest error:NULL];
      }
    } @finally {
      if (didStart)
        [url stopAccessingSecurityScopedResource];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (!s)
        return;
      [s dismissProgress];
      [s reloadDocuments];
      if (s.cancelRequested) {
        [s showSimpleAlertWithTitle:@"Copy Folder" message:@"Operation canceled."];
      } else if (hadError) {
        [s showSimpleAlertWithTitle:@"Copy Folder" message:@"Folder copy failed!"];
      } else {
        [s showSimpleAlertWithTitle:@"Copy Folder" message:@"Folder copied successfully!"];
      }
      s.cancelRequested = NO;
    });
  });
}

#pragma mark - Copy helpers (coordinated + recursive)

- (BOOL)copyItemAtURL:(NSURL *)src toDestinationURL:(NSURL *)dst error:(NSError **)outError {
  NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
  __block BOOL success = NO;
  __block NSError *coordErr = nil;

  __weak typeof(self) weakSelf = self;
  [coordinator
      coordinateReadingItemAtURL:src
                         options:0
                writingItemAtURL:dst
                         options:NSFileCoordinatorWritingForMerging
                           error:&coordErr
                      byAccessor:^(NSURL *_Nonnull coordinatedSrc, NSURL *_Nonnull coordinatedDst) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                          coordErr = [NSError errorWithDomain:NSCocoaErrorDomain
                                                         code:NSUserCancelledError
                                                     userInfo:@{NSLocalizedDescriptionKey : @"Owner deallocated"}];
                          success = NO;
                          return;
                        }

                        NSURL *stdSrc = [coordinatedSrc URLByStandardizingPath];
                        NSURL *stdDst = [coordinatedDst URLByStandardizingPath];
                        if ([stdSrc isEqual:stdDst]) {
                          success = YES;
                          return;
                        }

                        NSFileManager *fm = [[NSFileManager alloc] init];
                        NSError *err = nil;
                        NSNumber *isDirNumber = nil;
                        BOOL gotResource = [coordinatedSrc getResourceValue:&isDirNumber
                                                                     forKey:NSURLIsDirectoryKey
                                                                      error:&err];
                        if (!gotResource) {
                          coordErr = err;
                          NSLog(@"[DocumentsViewController] Failed to get "
                                @"resource value for %@: %@",
                                coordinatedSrc, err);
                          success = NO;
                          return;
                        }
                        BOOL isDir = [isDirNumber boolValue];

                        if (!isDir) {
                          NSURL *parent = [coordinatedDst URLByDeletingLastPathComponent];
                          if (![fm fileExistsAtPath:parent.path]) {
                            if (![fm createDirectoryAtURL:parent
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:&err]) {
                              coordErr = err;
                              success = NO;
                              return;
                            }
                          }
                          if ([fm fileExistsAtPath:coordinatedDst.path]) {
                            [fm removeItemAtURL:coordinatedDst error:NULL];
                          }
                          BOOL copyOK = [fm copyItemAtURL:coordinatedSrc toURL:coordinatedDst error:&err];
                          if (!copyOK) {
                            coordErr = err;
                            success = NO;
                            return;
                          }
                          success = YES;
                          return;
                        }

                        if (![fm fileExistsAtPath:coordinatedDst.path]) {
                          if (![fm createDirectoryAtURL:coordinatedDst
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&err]) {
                            coordErr = err;
                            success = NO;
                            return;
                          }
                        }

                        NSDirectoryEnumerator<NSURL *> *enumerator =
                            [fm enumeratorAtURL:coordinatedSrc
                                includingPropertiesForKeys:@[ NSURLIsDirectoryKey ]
                                                   options:NSDirectoryEnumerationSkipsHiddenFiles
                                              errorHandler:^BOOL(NSURL *_Nonnull url, NSError *_Nonnull error) {
                                                NSLog(@"[DocumentsViewController] "
                                                      @"Enumerator error for %@: %@",
                                                      url, error);
                                                return YES;
                                              }];

                        NSArray<NSString *> *srcComponents = coordinatedSrc.path.pathComponents;

                        for (NSURL *fileURL in enumerator) {
                          if (strongSelf.cancelRequested) {
                            [fm removeItemAtURL:coordinatedDst error:NULL];
                            coordErr = [NSError errorWithDomain:NSCocoaErrorDomain
                                                           code:NSUserCancelledError
                                                       userInfo:@{NSLocalizedDescriptionKey : @"User cancelled"}];
                            success = NO;
                            return;
                          }

                          NSArray<NSString *> *fileComponents = fileURL.path.pathComponents;
                          if (fileComponents.count < srcComponents.count) {
                            continue;
                          }
                          BOOL prefixMatch = YES;
                          for (NSUInteger i = 0; i < srcComponents.count; ++i) {
                            if (![srcComponents[i] isEqualToString:fileComponents[i]]) {
                              prefixMatch = NO;
                              break;
                            }
                          }
                          if (!prefixMatch) {
                            continue;
                          }

                          NSArray<NSString *> *relativeComponents =
                              (fileComponents.count > srcComponents.count)
                                  ? [fileComponents
                                        subarrayWithRange:NSMakeRange(srcComponents.count,
                                                                      fileComponents.count - srcComponents.count)]
                                  : @[];
                          NSString *relative = [NSString pathWithComponents:relativeComponents];
                          NSURL *targetURL = (relative.length > 0)
                                                 ? [coordinatedDst URLByAppendingPathComponent:relative]
                                                 : coordinatedDst;

                          NSNumber *isSubDirNumber = nil;
                          NSError *resErr = nil;
                          BOOL gotSub = [fileURL getResourceValue:&isSubDirNumber
                                                           forKey:NSURLIsDirectoryKey
                                                            error:&resErr];
                          if (!gotSub) {
                            coordErr = resErr;
                            [fm removeItemAtURL:coordinatedDst error:NULL];
                            success = NO;
                            return;
                          }
                          BOOL isSubDir = [isSubDirNumber boolValue];
                          if (isSubDir) {
                            if (![fm fileExistsAtPath:targetURL.path]) {
                              if (![fm createDirectoryAtURL:targetURL
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&resErr]) {
                                coordErr = resErr;
                                [fm removeItemAtURL:coordinatedDst error:NULL];
                                success = NO;
                                return;
                              }
                            }
                          } else {
                            if ([fm fileExistsAtPath:targetURL.path]) {
                              [fm removeItemAtURL:targetURL error:NULL];
                            }
                            NSError *fileErr = nil;
                            BOOL fileOK = [fm copyItemAtURL:fileURL toURL:targetURL error:&fileErr];
                            if (!fileOK) {
                              coordErr = fileErr;
                              [fm removeItemAtURL:coordinatedDst error:NULL];
                              success = NO;
                              return;
                            }
                          }
                        }

                        success = YES;
                      }];

  if (!success && outError) {
    *outError = coordErr;
  } else if (!success) {
    NSLog(@"[DocumentsViewController] copy failed for %@ -> %@ : %@", src, dst, coordErr);
  }
  return success;
}

#pragma mark - Table View

- (void)reloadDocuments {
  if (![NSThread isMainThread]) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      __strong typeof(weakSelf) s = weakSelf;
      if (s)
        [s reloadDocuments];
    });
    return;
  }
  NSURL *docsDir = [self appDocumentsDirectoryURL];
  NSError *dirErr = nil;
  NSArray<NSURL *> *contents = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:docsDir
      includingPropertiesForKeys:@[ NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLFileSizeKey ]
                         options:NSDirectoryEnumerationSkipsHiddenFiles
                           error:&dirErr];
  if (dirErr) {
    NSLog(@"[DocumentsViewController] Failed to list documents at %@: %@", docsDir, dirErr);
  }
  contents = [contents sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
    NSNumber *isDirA = nil;
    [a getResourceValue:&isDirA forKey:NSURLIsDirectoryKey error:NULL];
    NSNumber *isDirB = nil;
    [b getResourceValue:&isDirB forKey:NSURLIsDirectoryKey error:NULL];
    BOOL da = isDirA.boolValue, db = isDirB.boolValue;
    if (da != db)
      return da ? NSOrderedAscending : NSOrderedDescending;
    return [a.lastPathComponent.lowercaseString compare:b.lastPathComponent.lowercaseString];
  }];
  self.documentItems = contents ?: @[];
  [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.documentItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cellId = @"DocCell";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId forIndexPath:indexPath];
  cell.imageView.contentMode = UIViewContentModeScaleAspectFit;

  NSArray<NSURL *> *items = self.documentItems;
  if (indexPath.row < items.count) {
    NSURL *itemURL = items[indexPath.row];
    cell.textLabel.text = itemURL.lastPathComponent;

    NSNumber *isDirNumber = nil;
    [itemURL getResourceValue:&isDirNumber forKey:NSURLIsDirectoryKey error:NULL];
    BOOL isDir = [isDirNumber boolValue];
    cell.accessibilityLabel =
        [NSString stringWithFormat:@"%@ %@", isDir ? @"Folder" : @"File", itemURL.lastPathComponent];

    UIImage *icon = [DocumentsViewController iconForURL:itemURL size:CGSizeMake(28, 28)];
    if (icon) {
      if (@available(iOS 13.0, *)) {
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.tintColor = [UIColor systemBlueColor];
      } else {
        cell.imageView.tintColor = nil;
      }
      cell.imageView.image = icon;
    } else {
      cell.imageView.image = nil;
    }
  } else {
    cell.textLabel.text = @"";
    cell.imageView.image = nil;
  }

  return cell;
}

#pragma mark - Table selection (safeguarded)

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row >= self.documentItems.count) {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    return;
  }
  NSURL *itemURL = self.documentItems[indexPath.row];
  CGRect sourceRect = [tableView rectForRowAtIndexPath:indexPath];

  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:itemURL.lastPathComponent
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];

  __weak typeof(self) weakSelf = self;

  UIAlertAction *copy = [UIAlertAction
      actionWithTitle:@"Copy"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *_Nonnull action) {
                __strong typeof(self) s = weakSelf;
                if (!s)
                  return;

                NSURL *url = itemURL;
                CGRect srcRect = sourceRect;
                if (!url)
                  return;

                if (@available(iOS 14.0, *)) {
                  if ([UIDocumentPickerViewController instancesRespondToSelector:@selector(initForExportingURLs:
                                                                                                         asCopy:)]) {
                    UIDocumentPickerViewController *picker =
                        [[UIDocumentPickerViewController alloc] initForExportingURLs:@[ url ] asCopy:YES];
                    picker.delegate = s;
                    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                      picker.modalPresentationStyle = UIModalPresentationFormSheet;
                      picker.popoverPresentationController.sourceView = s.view;
                      picker.popoverPresentationController.sourceRect = srcRect;
                    }
                    s.exporting = YES;
                    [s presentViewController:picker animated:YES completion:nil];
                    return;
                  }
                }

                UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[ url ]
                                                                                 applicationActivities:nil];
                if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                  av.popoverPresentationController.sourceView = s.view;
                  av.popoverPresentationController.sourceRect = srcRect;
                }
                [s presentViewController:av animated:YES completion:nil];
              }];
  [sheet addAction:copy];

  UIAlertAction *rename = [UIAlertAction
      actionWithTitle:@"Rename"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *_Nonnull action) {
                __strong typeof(self) s = weakSelf;
                if (!s)
                  return;
                UIAlertController *prompt = [UIAlertController alertControllerWithTitle:@"Rename"
                                                                                message:@"Enter new name"
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                [prompt addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                  textField.text = itemURL.lastPathComponent;
                }];
                [prompt addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                [prompt addAction:[UIAlertAction
                                      actionWithTitle:@"OK"
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *_Nonnull a) {
                                                __strong typeof(self) ss = weakSelf;
                                                if (!ss)
                                                  return;
                                                NSString *newName = prompt.textFields.firstObject.text;
                                                if (newName.length == 0)
                                                  return;
                                                NSURL *dest = [itemURL URLByDeletingLastPathComponent];
                                                dest = [dest URLByAppendingPathComponent:newName];
                                                if ([[NSFileManager defaultManager] fileExistsAtPath:dest.path]) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                    UIAlertController *errAlert = [UIAlertController
                                                        alertControllerWithTitle:@"Rename failed"
                                                                         message:@"A file or folder with that name "
                                                                                 @"already exists."
                                                                  preferredStyle:UIAlertControllerStyleAlert];
                                                    [errAlert addAction:[UIAlertAction
                                                                            actionWithTitle:@"OK"
                                                                                      style:UIAlertActionStyleCancel
                                                                                    handler:nil]];
                                                    [ss presentViewController:errAlert animated:YES completion:nil];
                                                  });
                                                  return;
                                                }
                                                NSError *mvErr = nil;
                                                if (![[NSFileManager defaultManager] moveItemAtURL:itemURL
                                                                                             toURL:dest
                                                                                             error:&mvErr]) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                    UIAlertController *errAlert = [UIAlertController
                                                        alertControllerWithTitle:@"Rename failed"
                                                                         message:mvErr.localizedDescription
                                                                  preferredStyle:UIAlertControllerStyleAlert];
                                                    [errAlert addAction:[UIAlertAction
                                                                            actionWithTitle:@"OK"
                                                                                      style:UIAlertActionStyleCancel
                                                                                    handler:nil]];
                                                    [ss presentViewController:errAlert animated:YES completion:nil];
                                                  });
                                                } else {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                    [ss reloadDocuments];
                                                  });
                                                }
                                              }]];
                [s presentViewController:prompt animated:YES completion:nil];
              }];
  [sheet addAction:rename];

  UIAlertAction *delete = [UIAlertAction
      actionWithTitle:@"Delete"
                style:UIAlertActionStyleDestructive
              handler:^(UIAlertAction *_Nonnull action) {
                __strong typeof(self) s = weakSelf;
                if (!s)
                  return;
                UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete"
                                                                                 message:@"Are you sure?"
                                                                          preferredStyle:UIAlertControllerStyleAlert];
                [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                            style:UIAlertActionStyleCancel
                                                          handler:nil]];
                [confirm addAction:[UIAlertAction
                                       actionWithTitle:@"Delete"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *_Nonnull act) {
                                                 NSError *delErr = nil;
                                                 if (![[NSFileManager defaultManager] removeItemAtURL:itemURL
                                                                                                error:&delErr]) {
                                                   UIAlertController *errAlert = [UIAlertController
                                                       alertControllerWithTitle:@"Delete failed"
                                                                        message:delErr.localizedDescription
                                                                 preferredStyle:UIAlertControllerStyleAlert];
                                                   [errAlert
                                                       addAction:[UIAlertAction actionWithTitle:@"OK"
                                                                                          style:UIAlertActionStyleCancel
                                                                                        handler:nil]];
                                                   [s presentViewController:errAlert animated:YES completion:nil];
                                                 } else {
                                                   [s reloadDocuments];
                                                 }
                                               }]];
                [s presentViewController:confirm animated:YES completion:nil];
              }];
  [sheet addAction:delete];

  [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

  if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    sheet.popoverPresentationController.sourceView = tableView;
    sheet.popoverPresentationController.sourceRect = sourceRect;
  }

  [self presentViewController:sheet animated:YES completion:nil];
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Progress & Alerts

- (void)showProgressWithMessage:(NSString *)message {
  if (![NSThread isMainThread]) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      __strong typeof(self) s = weakSelf;
      if (s)
        [s showProgressWithMessage:message];
    });
    return;
  }

  if (self.progressAlert && self.presentedViewController == self.progressAlert)
    return;
  self.cancelRequested = NO;

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:message
                                                                 message:@"\n\n\n"
                                                          preferredStyle:UIAlertControllerStyleAlert];

  UIActivityIndicatorView *indicator;
  if (@available(iOS 13.0, *)) {
    indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    indicator.color = [UIColor systemGrayColor];
  } else {
    indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicator.color = [UIColor grayColor];
  }
  [indicator startAnimating];
  indicator.translatesAutoresizingMaskIntoConstraints = NO;
  [alert.view addSubview:indicator];

  [NSLayoutConstraint activateConstraints:@[
    [indicator.centerXAnchor constraintEqualToAnchor:alert.view.centerXAnchor],
    [indicator.topAnchor constraintEqualToAnchor:alert.view.topAnchor constant:52.0],
    [indicator.widthAnchor constraintEqualToConstant:40.0],
    [indicator.heightAnchor constraintEqualToConstant:40.0],
  ]];

  __weak typeof(self) weakSelf = self;
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                            style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction *_Nonnull action) {
                                            __strong typeof(self) s = weakSelf;
                                            if (s)
                                              s.cancelRequested = YES;
                                          }]];

  self.progressAlert = alert;
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissProgress {
  if (![NSThread isMainThread]) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      __strong typeof(self) s = weakSelf;
      if (s)
        [s dismissProgress];
    });
    return;
  }

  UIViewController *presented = self.presentedViewController;
  UIAlertController *stored = self.progressAlert;
  if (presented && stored && presented == stored) {
    __weak typeof(self) weakSelf = self;
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               __strong typeof(weakSelf) s = weakSelf;
                               if (s)
                                 s.progressAlert = nil;
                             }];
    return;
  }

  self.progressAlert = nil;
}

- (void)showSimpleAlertWithTitle:(NSString *)title message:(NSString *)msg {
  dispatch_async(dispatch_get_main_queue(), ^{
    void (^presentAlertBlock)(void) = ^{
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                     message:msg
                                                              preferredStyle:UIAlertControllerStyleAlert];
      [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
      [self presentViewController:alert animated:YES completion:nil];
    };

    if (self.progressAlert && self.presentedViewController == self.progressAlert) {
      self.progressAlert = nil;
      [self dismissViewControllerAnimated:YES completion:presentAlertBlock];
    } else {
      presentAlertBlock();
    }
  });
}

- (void)showFileExistsAlert:(NSString *)name {
  NSString *msg = [NSString stringWithFormat:@"A file or folder named \"%@\" already exists in the "
                                             @"destination. Operation stopped.",
                                             name];
  [self showSimpleAlertWithTitle:@"File or Folder exists" message:msg];
}

#pragma mark - Utilities

- (NSURL *)appDocumentsDirectoryURL {
  NSURL *docsDir = self.baseURL;
  if (!docsDir) {
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    docsDir = (urls.count > 0) ? urls.firstObject : nil;
  }
  return docsDir;
}

- (void)cleanUpCopyingArtifacts {
  NSURL *root = [self appDocumentsDirectoryURL];
  if (!root)
    return;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray<NSURL *> *children = [fm contentsOfDirectoryAtURL:root includingPropertiesForKeys:nil options:0 error:nil];
  for (NSURL *u in children) {
    if ([u.lastPathComponent hasSuffix:@".copying"] ||
        ([u.lastPathComponent hasPrefix:@"."] && [u.lastPathComponent containsString:@".copying"])) {
      [fm removeItemAtURL:u error:NULL];
    } else {
      NSNumber *isDir = nil;
      [u getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
      if ([isDir boolValue]) {
        NSArray<NSURL *> *sub = [fm contentsOfDirectoryAtURL:u includingPropertiesForKeys:nil options:0 error:nil];
        for (NSURL *s in sub) {
          if ([s.lastPathComponent hasSuffix:@".copying"]) {
            [fm removeItemAtURL:s error:NULL];
          }
        }
      }
    }
  }
}

#pragma mark - Icon helper

+ (UIImage *)iconForURL:(NSURL *)url size:(CGSize)size {
  if (size.width <= 0 || size.height <= 0) {
    size = CGSizeMake(28.0, 28.0);
  }

  NSNumber *isDirNumber = nil;
  NSError *err = nil;
  BOOL ok = [url getResourceValue:&isDirNumber forKey:NSURLIsDirectoryKey error:&err];
  BOOL isDir = (ok && isDirNumber) ? [isDirNumber boolValue] : NO;

  if (@available(iOS 13.0, *)) {
    NSString *name = isDir ? @"folder" : @"doc.text";
    CGFloat pointSize = roundf(MIN(size.width, size.height) * 0.75);
    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightRegular];
    UIImage *img = [UIImage systemImageNamed:name withConfiguration:config];
    if (img) {
      return img;
    }
  }

  NSString *emoji = isDir ? @"📁" : @"📄";
  UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
  UIFont *font = [UIFont systemFontOfSize:roundf(size.height * 0.9)];
  NSDictionary *attrs = @{NSFontAttributeName : font};
  CGSize textSize = [emoji sizeWithAttributes:attrs];
  CGRect r = CGRectMake((size.width - textSize.width) / 2.0, (size.height - textSize.height) / 2.0, textSize.width,
                        textSize.height);
  [emoji drawInRect:r withAttributes:attrs];
  UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return result;
}

@end
