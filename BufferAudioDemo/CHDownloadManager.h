//
//  CHDownloadManager.h
//  BufferAudioDemo
//
//  用于下载在线音频文件
//
//  Created by chunhaixu on 16/2/28.
//  Copyright © 2016年 SL. All rights reserved.
//

#import <Foundation/Foundation.h>

//先使用进度更新的方法
@protocol CHDownloadManagerDelegate <NSObject>
@optional
-(void)downloadingAudioProgress:(float)progress receivedLength:(long long)receive totalLength:(long long)total;
-(void)downloadingError:(NSError*)error;
@end

@interface CHDownloadManager : NSObject

@property(nonatomic,weak) id<CHDownloadManagerDelegate> delegate;
@property(nonatomic,readonly) NSString *filePath;

-(instancetype)initWithUrl:(NSString*)url;

///开始下载音频文件
-(void)downloadAudio;

@end
