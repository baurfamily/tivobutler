//
//  TiVo_FS_Controller.h
//  TiVo FS
//
//  Created by Eric Baur on 10/17/09.
//  Copyright 2009 Eric Shore Baur. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@class GMUserFileSystem;
@class TiVo_FS_Controller;

@interface TiVo_FS_Controller : NSObject {
  GMUserFileSystem* fs_;
  TiVo_FS_Controller* fs_delegate_;
}

@end
