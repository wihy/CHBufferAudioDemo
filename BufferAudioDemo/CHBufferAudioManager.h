//
//  CHBufferAudioManager.h
//  BufferAudioDemo
//
//  Created by chunhaixu on 16/2/27.
//  Copyright © 2016年 SL. All rights reserved.
//

///
//      CHBufferAudioManager  用于缓存和播放
//      CHDownloadManager  用于独立下载音频数据
//
//      ----------------------------
//      |                           |
//      | CHBufferAudioManager      |
//      |       缓存播放模块          |
//      |                           |
//      |   |--------------—--|     |
//      |   |CHDownloadManager|     |
//      |   |   下载模块       |     |
//      |   |                 |     |
//      |---------------------------|
//
//
//

#import <Foundation/Foundation.h>


@protocol CHBufferAudioManagerDelegate <NSObject>

@optional
-(void)audioBufferingProgress:(float)progress receivedLength:(long long)receive totalLength:(long long)total;
-(void)audioBufferDidFailed:(NSError*)error;

@end

@interface CHBufferAudioManager : NSObject

@property(nonatomic,weak) id<CHBufferAudioManagerDelegate> delegate;//回调代理

-(instancetype)initWithUrl:(NSString*)url;
+(instancetype)bufferManagerWithAudioUrl:(NSString*)url;

-(void)startBuffering;
-(void)stopBuffering;

@end
