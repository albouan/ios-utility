#import <UIKit/UIKit.h>

@interface DocumentsViewController
    : UIViewController <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>

+ (void)launchFrom:(UIViewController *)presenter;

@end
