//
//  CHBufferAudioManager.m
//  BufferAudioDemo
//
//  Created by chunhaixu on 16/2/27.
//  Copyright © 2016年 SL. All rights reserved.
//

#import "CHBufferAudioManager.h"
#import "CHDownloadManager.h"
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioFile.h>

#define NUM_BUFFERS 3

@interface CHBufferAudioManager ()<CHDownloadManagerDelegate>
{
    AudioFileID _audioFile;
    //音频队列
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _buffers[NUM_BUFFERS];
    AudioStreamPacketDescription *_packetDescs;
    
    SInt64 _packetIndex;
    UInt32 _numPacketsToRead;
    UInt32 _bufferByteSize;
}

@property(nonatomic,copy) NSString *urlPath;
@property(nonatomic,copy) CHDownloadManager *downloadManager;

@end

@implementation CHBufferAudioManager

-(instancetype)initWithUrl:(NSString*)url{
    if (self = [super init]) {
        _urlPath = url;
        _downloadManager = [[CHDownloadManager alloc] initWithUrl:_urlPath];
        _downloadManager.delegate = self;
        [_downloadManager downloadAudio];
    }
    return self;
}

+(instancetype)bufferManagerWithAudioUrl:(NSString*)url{
    CHBufferAudioManager *bufferManager = [[CHBufferAudioManager alloc] initWithUrl:url];
    return bufferManager;
}


-(void)startBuffering{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //设置并缓存数据
        NSString *filePath = self.downloadManager.filePath;
        [self bufferAudioWithPath:filePath];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            OSStatus result = AudioQueueStart(_audioQueue, NULL);
            if (result != noErr) {
                NSLog(@"播放音频失败。。。");
            }
        });
    });
    
}

-(void)stopBuffering{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OSStatus result =  AudioQueueStop(_audioQueue, YES);
        if (result != noErr) {
            NSLog(@"停止音频播放失败。。。");
        }
    });
}

#pragma mark -- 用于缓存数据
//用于回调
static void CHBufferCallBack(void * __nullable       inUserData,
                             AudioQueueRef           inAQ,
                             AudioQueueBufferRef     inBuffer){
    CHBufferAudioManager* bufferAudio = (__bridge CHBufferAudioManager*)inUserData;
    [bufferAudio audioQueueOutputWithQueue:inAQ queueBuffer:inBuffer];
}

-(void)bufferAudioWithPath:(NSString*)path{
    
    NSURL *audioFileURL = [NSURL fileURLWithPath:path];
    AudioFileTypeID fileTypeID = kAudioFileMP3Type;
    if ([audioFileURL.lastPathComponent containsString:@"m4a"]){
        fileTypeID = kAudioFileM4AType;
    }else{
        fileTypeID = 0;
    }
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)audioFileURL, kAudioFileReadPermission, fileTypeID, &_audioFile);
    if (status != noErr) {
        NSLog(@"打开音频文件失败。。。status = %d",status);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"获取文件失败" code:102 userInfo:@{NSUnderlyingErrorKey:@"获取音频文件失败"}];
            if ([self.delegate respondsToSelector:@selector(audioBufferDidFailed:)]) {
                [self.delegate audioBufferDidFailed:error];
            }
        });
        return;
    }

    //取得音频数据格式
    AudioStreamBasicDescription _dataFormat;
    UInt32 size = sizeof(_dataFormat);
    AudioFileGetProperty(_audioFile, kAudioFilePropertyDataFormat, &size, &_dataFormat);
    
    
    AudioQueueNewOutput(&_dataFormat, CHBufferCallBack, (__bridge void *)(self),
                        NULL, NULL, 0, &_audioQueue);
    UInt32 maxPacketSize;
    UInt32 gBufferSizeBytes=0x10000;
    //计算单位时间包含的包数
    if (_dataFormat.mBytesPerPacket == 0 || _dataFormat.mFramesPerPacket == 0) {
        size = sizeof(maxPacketSize);
        AudioFileGetProperty(_audioFile, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
        if (maxPacketSize > gBufferSizeBytes) {
            maxPacketSize = gBufferSizeBytes;
        }
        _numPacketsToRead = gBufferSizeBytes/maxPacketSize;
        _packetDescs = malloc(sizeof(AudioStreamPacketDescription)*_numPacketsToRead);
    }else {
        _numPacketsToRead = gBufferSizeBytes/_dataFormat.mBytesPerPacket;
        _packetDescs = nil;
    }
    //创建并分配缓冲空间
    _packetIndex=0;
    for (int i=0; i< NUM_BUFFERS; i++) {
        AudioQueueAllocateBuffer(_audioQueue, gBufferSizeBytes, &_buffers[i]);
        //读取包数据
        if ([self readPacketsIntoBuffer:_buffers[i]]) {
            break;
        }
    }

    //设置音量
    AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, 1.0);
}

//缓存数据读取方法的实现
-(void)audioQueueOutputWithQueue:(AudioQueueRef)audioQueue queueBuffer:(AudioQueueBufferRef)audioQueueBuffer{
    
    UInt32 numBytes;
    UInt32 numPackets = _numPacketsToRead;
    OSStatus status = AudioFileReadPackets(_audioFile, NO, &numBytes, _packetDescs, _packetIndex,&numPackets, audioQueueBuffer->mAudioData);
    if (numPackets > 0) {
        audioQueueBuffer->mAudioDataByteSize = numBytes;
        status = AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffer, numPackets, _packetDescs);
        _packetIndex += numPackets;
    }
}


-(BOOL)readPacketsIntoBuffer:(AudioQueueBufferRef)buffer {
    UInt32 numBytes,numPackets;
    
    //从文件中接受数据并保存到缓存(buffer)中
    numPackets = _numPacketsToRead;
    AudioFileReadPackets(_audioFile, NO, &numBytes, _packetDescs, _packetIndex, &numPackets, buffer->mAudioData);
    if(numPackets >0){
        buffer->mAudioDataByteSize = numBytes;
        AudioQueueEnqueueBuffer(_audioQueue, buffer, (_packetDescs ? numPackets : 0), _packetDescs);
        _packetIndex += numPackets;
    }else{
        return NO;
    }
    return YES;
}

#pragma mark -- CHDownloadManagerDelegate
-(void)downloadingAudioProgress:(float)progress receivedLength:(long long)receive totalLength:(long long)total{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(audioBufferingProgress:receivedLength:totalLength:)]) {
            [self.delegate audioBufferingProgress:progress receivedLength:receive totalLength:total];
        }
    });
}
-(void)downloadingError:(NSError*)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(audioBufferDidFailed:)]) {
            [self.delegate audioBufferDidFailed:error];
        }
    });
}

@end
