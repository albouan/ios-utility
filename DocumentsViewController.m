#import "DocumentsViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface DocumentsViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UIButton *fileCopyButton;
@property(nonatomic, strong) UIButton *folderCopyButton;
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

- (BOOL)isBusy {
  return (self.progressAlert != nil);
}

- (void)updateUIEnabled:(BOOL)enabled {
  self.tableView.userInteractionEnabled = enabled;
  self.fileCopyButton.enabled = enabled;
  self.folderCopyButton.enabled = enabled;
  self.navigationItem.leftBarButtonItem.enabled = enabled;

  if (self.navigationController) {
    self.navigationController.modalInPresentation = !enabled;
  }
}

+ (void)launchFrom:(UIViewController *)presenter {
  DocumentsViewController *vc = [[DocumentsViewController alloc] init];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  [presenter presentViewController:nav animated:YES completion:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = [UIColor systemBackgroundColor];

  self.navigationItem.leftBarButtonItem =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                    target:self
                                                    action:@selector(close)];

  UILabel *titleLabel = [[UILabel alloc] init];
  titleLabel.text = @"Documents Browser";
  titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
  titleLabel.adjustsFontForContentSizeCategory = YES;
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.textAlignment = NSTextAlignmentCenter;

  self.fileCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.fileCopyButton setTitle:@"Copy File to App Documents" forState:UIControlStateNormal];
  [self.fileCopyButton addTarget:self action:@selector(copyFile) forControlEvents:UIControlEventTouchUpInside];
  self.fileCopyButton.translatesAutoresizingMaskIntoConstraints = NO;

  self.folderCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.folderCopyButton setTitle:@"Copy Folder to App Documents" forState:UIControlStateNormal];
  [self.folderCopyButton addTarget:self action:@selector(copyFolder) forControlEvents:UIControlEventTouchUpInside];
  self.folderCopyButton.translatesAutoresizingMaskIntoConstraints = NO;

  self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DocCell"];
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:titleLabel];
  [self.view addSubview:self.fileCopyButton];
  [self.view addSubview:self.folderCopyButton];
  [self.view addSubview:self.tableView];

  UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12.0],
    [titleLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],

    [self.fileCopyButton.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
    [self.fileCopyButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
    [self.fileCopyButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],

    [self.folderCopyButton.topAnchor constraintEqualToAnchor:self.fileCopyButton.bottomAnchor constant:8.0],
    [self.folderCopyButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
    [self.folderCopyButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],

    [self.tableView.topAnchor constraintEqualToAnchor:self.folderCopyButton.bottomAnchor constant:12.0],
    [self.tableView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
    [self.tableView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
    [self.tableView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor]
  ]];

  UILabel *tableHeader = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, self.view.bounds.size.width - 32, 44)];
  UIFont *base = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
  tableHeader.font = [UIFont boldSystemFontOfSize:base.pointSize];
  tableHeader.adjustsFontForContentSizeCategory = YES;
  tableHeader.text = @"App Documents:";
  tableHeader.textAlignment = NSTextAlignmentLeft;
  tableHeader.numberOfLines = 1;
  tableHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  self.tableView.tableHeaderView = tableHeader;

  [self cleanUpCopyingArtifacts];
  [self reloadDocuments];
}

- (void)close {
  if ([self isBusy]) {
    return;
  }
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Actions

- (void)copyFile {
  if ([self isBusy]) {
    return;
  }
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[ UTTypeItem ]];
  picker.delegate = self;
  picker.allowsMultipleSelection = YES;
  [self presentViewController:picker animated:YES completion:nil];
}

- (void)copyFolder {
  if ([self isBusy]) {
    return;
  }
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[ UTTypeFolder ]];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  [controller dismissViewControllerAnimated:YES completion:nil];
  if (self.exporting) {
    self.exporting = NO;
    return;
  }

  if (!urls || urls.count == 0) {
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
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
  });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  [controller dismissViewControllerAnimated:YES completion:nil];
  if (self.exporting) {
    self.exporting = NO;
  }
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
                                       @"name. Rename files before copying."];
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
    __block BOOL hadError = NO;

    for (NSURL *src in urls) {
      if (!s)
        break;
      
      __block BOOL shouldCancel = NO;
      if ([s isOnSyncQueue]) {
        shouldCancel = s.cancelRequestedBacking;
      } else {
        dispatch_sync(s.syncQueue, ^{
          shouldCancel = s.cancelRequestedBacking;
        });
      }
      if (shouldCancel)
        break;

      BOOL didStart = [src startAccessingSecurityScopedResource];
      if (!didStart) {
        hadError = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
          __strong typeof(self) ss = weakSelf;
          if (ss)
            [ss showSimpleAlertWithTitle:@"Access denied" message:@"Unable to access selected file(s)."];
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
            __strong typeof(self) ss = weakSelf;
            if (ss)
              [ss showFileExistsAlert:name];
          });
          break;
        }

        NSError *err = nil;
        BOOL ok = [s copyItemAtURL:src toDestinationURL:tempDest error:&err];
        if (!ok || err) {
          hadError = YES;
          [fm removeItemAtURL:tempDest error:NULL];
          dispatch_async(dispatch_get_main_queue(), ^{
            [s showSimpleAlertWithTitle:@"Copy Failed"
                                message:err.localizedDescription ?: @"An unknown error occurred during copy."];
          });
          break;
        }

        __block BOOL isCancelled = NO;
        if ([s isOnSyncQueue]) {
          isCancelled = s.cancelRequestedBacking;
        } else {
          dispatch_sync(s.syncQueue, ^{
            isCancelled = s.cancelRequestedBacking;
          });
        }
        if (!isCancelled) {
          if (![fm moveItemAtURL:tempDest toURL:finalDest error:&err]) {
            hadError = YES;
            [fm removeItemAtURL:tempDest error:NULL];

            dispatch_async(dispatch_get_main_queue(), ^{
              __strong typeof(self) ss = weakSelf;
              if (ss) {
                [ss showSimpleAlertWithTitle:@"Copy Failed"
                                    message:err.localizedDescription ?: @"Failed to finalize copied file."];
              }
            });
            break;
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
      __strong typeof(self) ss = weakSelf;
      if (!ss)
        return;

      BOOL wasCanceled = ss.cancelRequested;

      [ss setExporting:NO];
      [ss setCancelRequested:NO];
      [ss reloadDocuments];

      if (!hadError && wasCanceled) {
        [ss showSimpleAlertWithTitle:@"Canceled" message:@"The copy operation was canceled."];
      } else if (!hadError) {
        [ss showSimpleAlertWithTitle:@"Copy Complete" message:@"Files copied successfully."];
      }
    });
  });
}

- (void)startImportFolderFromURL:(NSURL *)url {
  if (!url)
    return;
  
  [self showProgressWithMessage:@"Copying folder..."];

  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    __strong typeof(self) s = weakSelf;
    if (!s)
      return;

    BOOL didStart = [url startAccessingSecurityScopedResource];
    if (!didStart) {
      dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) ss = weakSelf;
        if (ss) {
          [ss setExporting:NO];
          [ss setCancelRequested:NO];
          [ss showSimpleAlertWithTitle:@"Access denied" message:@"Unable to access the selected folder."];
        }
      });
      return;
    }

    @try {
      NSString *folderName = url.lastPathComponent;
      NSURL *docsDir = [s appDocumentsDirectoryURL];
      NSURL *finalDest = [docsDir URLByAppendingPathComponent:folderName];
      NSURL *tempDest = [docsDir URLByAppendingPathComponent:[NSString stringWithFormat:@".%@.copying", folderName]];

      NSFileManager *fm = [[NSFileManager alloc] init];
      if ([fm fileExistsAtPath:finalDest.path] || [fm fileExistsAtPath:tempDest.path]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          __strong typeof(self) ss = weakSelf;
          if (ss) {
            [ss setExporting:NO];
            [ss setCancelRequested:NO];
            [ss showFileExistsAlert:folderName];
          }
        });
        return;
      }

      NSError *err = nil;
      BOOL ok = [s copyItemAtURL:url toDestinationURL:tempDest error:&err];

      BOOL wasCanceled = s.cancelRequested;

      if (wasCanceled) {
        [fm removeItemAtURL:tempDest error:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{
          __strong typeof(self) ss = weakSelf;
          if (ss) {
            [ss setExporting:NO];
            [ss setCancelRequested:NO];
            [ss reloadDocuments];
            [ss showSimpleAlertWithTitle:@"Canceled" message:@"The folder copy was canceled."];
          }
        });
        return;
      }

      if (!ok || err) {
        [fm removeItemAtURL:tempDest error:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{
          __strong typeof(self) ss = weakSelf;
          if (ss) {
            [ss setExporting:NO];
            [ss setCancelRequested:NO];
            [ss showSimpleAlertWithTitle:@"Copy Failed"
                                 message:err.localizedDescription ?: @"An unknown error occurred during folder copy."];
          }
        });
        return;
      }

      if (![fm moveItemAtURL:tempDest toURL:finalDest error:&err]) {
        [fm removeItemAtURL:tempDest error:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{
          __strong typeof(self) ss = weakSelf;
          if (ss) {
            [ss setExporting:NO];
            [ss setCancelRequested:NO];
            [ss showSimpleAlertWithTitle:@"Copy Failed"
                                 message:err.localizedDescription ?: @"Failed to finalize copied folder."];
          }
        });
        return;
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) ss = weakSelf;
        if (ss) {
          [ss setExporting:NO];
          [ss setCancelRequested:NO];
          [ss reloadDocuments];
          [ss showSimpleAlertWithTitle:@"Copy Complete" message:@"Folder copied successfully."];
        }
      });

    } @finally {
      [url stopAccessingSecurityScopedResource];
    }
  });
}

#pragma mark - Copy helpers (coordinated + recursive)

- (BOOL)copyItemAtURL:(NSURL *)src toDestinationURL:(NSURL *)dst error:(NSError **)outError {
  NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
  __block BOOL success = NO;
  __block NSError *coordErr = nil;

  if (self.cancelRequested) {
    if (outError) {
      *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
    }
    return NO;
  }

  [coordinator coordinateReadingItemAtURL:src
                                  options:0
                                    error:&coordErr
                               byAccessor:^(NSURL *newURL) {
    if (self.cancelRequested) {
      coordErr = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
      return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:dst.path]) {
      coordErr = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSFileWriteFileExistsError
                                 userInfo:@{NSURLErrorKey : dst}];
      success = NO;
      return;
    }

    BOOL isDir = NO;
    if ([fm fileExistsAtPath:newURL.path isDirectory:&isDir] && isDir) {
      if (![fm createDirectoryAtURL:dst withIntermediateDirectories:YES attributes:nil error:&coordErr]) {
        return;
      }
      NSArray<NSURL *> *children = [fm contentsOfDirectoryAtURL:newURL
                                      includingPropertiesForKeys:@[ NSURLNameKey ]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:&coordErr];
      if (coordErr) {
        return;
      }
      for (NSURL *childSrc in children) {
        if (self.cancelRequested) {
          coordErr = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
          return;
        }
        NSURL *childDst = [dst URLByAppendingPathComponent:childSrc.lastPathComponent];
        if (![self copyItemAtURL:childSrc toDestinationURL:childDst error:&coordErr]) {
          return;
        }
      }
      success = YES;
    } else {
      success = [fm copyItemAtURL:newURL toURL:dst error:&coordErr];
    }
  }];

  if (!success && outError && !*outError) {
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
      icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
      cell.imageView.tintColor = [UIColor systemBlueColor];
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
  if ([self isBusy]) {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    return;
  }

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

  UIAlertAction *copy =
      [UIAlertAction actionWithTitle:@"Copy"
                               style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction *_Nonnull action) {
                               __strong typeof(self) s = weakSelf;
                               if (!s)
                                 return;

                               NSURL *url = itemURL;
                               CGRect srcRect = sourceRect;
                               if (!url)
                                 return;

                               UIDocumentPickerViewController *picker =
                                   [[UIDocumentPickerViewController alloc] initForExportingURLs:@[ url ] asCopy:YES];
                               picker.delegate = s;

                               UIPopoverPresentationController *pop = picker.popoverPresentationController;
                               if (pop) {
                                 pop.sourceView = tableView;
                                 pop.sourceRect = srcRect;
                               }

                               s.exporting = YES;
                               [s presentViewController:picker animated:YES completion:nil];
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
                                                
                                                [ss showProgressWithMessage:@"Renaming..."];
                                                
                                                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                                                  __strong typeof(self) sss = weakSelf;
                                                  if (!sss) return; 
                                                  
                                                  NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
                                                  __block NSError *mvErr = nil;
                                                  __block BOOL success = NO;
                                                  
                                                  [coordinator coordinateWritingItemAtURL:itemURL
                                                                                  options:NSFileCoordinatorWritingForMoving
                                                                         writingItemAtURL:dest
                                                                                  options:NSFileCoordinatorWritingForReplacing
                                                                                    error:&mvErr
                                                                               byAccessor:^(NSURL *srcURL, NSURL *dstURL) {
                                                    NSFileManager *fm = [[NSFileManager alloc] init];
                                                    success = [fm moveItemAtURL:srcURL toURL:dstURL error:&mvErr];
                                                  }];
                                                  
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                    __strong typeof(self) sss = weakSelf;
                                                    if (!sss) return;
                                                    
                                                    [sss reloadDocuments];
                                                    
                                                    if (!success) {
                                                      [sss showSimpleAlertWithTitle:@"Rename failed"
                                                                            message:mvErr.localizedDescription ?: @"Unknown error"];
                                                    } else {
                                                      [sss showSimpleAlertWithTitle:@"Renamed" message:@"Item was renamed successfully."];
                                                    }
                                                  });
                                                });
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
                                                 __strong typeof(self) ss = weakSelf;
                                                 if (!ss) return;
                                                 
                                                 [ss showProgressWithMessage:@"Deleting..."];
                                                 
                                                 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                                                  __strong typeof(self) sss = weakSelf;
                                                  if (!sss) return;

                                                   NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
                                                   __block NSError *delErr = nil;
                                                   __block BOOL success = NO;
                                                   
                                                   [coordinator coordinateWritingItemAtURL:itemURL
                                                                                   options:NSFileCoordinatorWritingForDeleting
                                                                                     error:&delErr
                                                                                byAccessor:^(NSURL *coordURL) {
                                                     NSFileManager *fm = [[NSFileManager alloc] init];
                                                     success = [fm removeItemAtURL:coordURL error:&delErr];
                                                   }];
                                                   
                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                     __strong typeof(self) sss = weakSelf;
                                                     if (!sss) return;
                                                     
                                                     [sss reloadDocuments];
                                                     
                                                     if (!success) {
                                                       [sss showSimpleAlertWithTitle:@"Delete failed"
                                                                             message:delErr.localizedDescription ?: @"Unknown error"];
                                                     } else {
                                                       [sss showSimpleAlertWithTitle:@"Deleted" message:@"Item was deleted successfully."];
                                                     }
                                                   });
                                                 });
                                               }]];
                [s presentViewController:confirm animated:YES completion:nil];
              }];
  [sheet addAction:delete];

  [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

  UIPopoverPresentationController *pop = sheet.popoverPresentationController;
  if (pop) {
    pop.sourceView = tableView;
    pop.sourceRect = sourceRect;
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
  [self updateUIEnabled:NO];

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:message
                                                                 message:@"\n\n\n"
                                                          preferredStyle:UIAlertControllerStyleAlert];

  UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  indicator.color = [UIColor systemGrayColor];
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

  UIAlertController *stored = self.progressAlert;
  if (!stored) {
    [self updateUIEnabled:YES];
    return;
  }

  UIViewController *presented = self.presentedViewController;
  if (presented == stored) {
    [self dismissViewControllerAnimated:YES completion:^{
      if (self.progressAlert == stored) {
        self.progressAlert = nil;
        [self updateUIEnabled:YES];
      }
    }];
  } else {
    self.progressAlert = nil;
    [self updateUIEnabled:YES];
  }
}

- (void)showSimpleAlertWithTitle:(NSString *)title message:(NSString *)msg {
  dispatch_async(dispatch_get_main_queue(), ^{
    void (^presentFinalAlert)(void) = ^{
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                     message:msg
                                                              preferredStyle:UIAlertControllerStyleAlert];
      [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
      [self presentViewController:alert animated:YES completion:nil];
    };

    UIAlertController *progress = self.progressAlert;
    if (progress && self.presentedViewController == progress) {
      UIAlertController *stored = progress;
      [self dismissViewControllerAnimated:YES
                               completion:^{
                                 if (self.progressAlert == stored) {
                                   self.progressAlert = nil;
                                 }
                                 [self setExporting:NO];
                                 [self setCancelRequested:NO];
                                 [self updateUIEnabled:YES];
                                 presentFinalAlert();
                               }];
    } else {
      self.progressAlert = nil;
      [self setExporting:NO];
      [self setCancelRequested:NO];
      [self updateUIEnabled:YES];
      presentFinalAlert();
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

  NSString *name = isDir ? @"folder" : @"doc.text";
  CGFloat pointSize = roundf(MIN(size.width, size.height) * 0.75);
  UIImageSymbolConfiguration *config =
      [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightRegular];
  return [UIImage systemImageNamed:name withConfiguration:config];
}

@end
