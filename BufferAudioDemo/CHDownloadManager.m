//
//  CHDownloadManager.m
//  BufferAudioDemo
//
//  Created by chunhaixu on 16/2/28.
//  Copyright © 2016年 SL. All rights reserved.
//

#import "CHDownloadManager.h"

@interface CHDownloadManager ()<NSURLConnectionDataDelegate>

@property(nonatomic,copy) NSString *filePath;
@property(nonatomic,copy) NSString *audioUrl;
@property(nonatomic,assign) long long receiveLength;
@property(nonatomic,assign) long long totalLength;
@property(nonatomic,strong) NSFileHandle *audioFileHandle;
@property(nonatomic,strong) NSOperationQueue *operationQueue;

@end

@implementation CHDownloadManager

- (instancetype)initWithUrl:(NSString*)url
{
    self = [super init];
    if (self) {
        _audioUrl = url;
        _operationQueue = [[NSOperationQueue alloc] init];
        _filePath = [self audioFilePathWithUrl:url];
    }
    return self;
}

//创建与url对应的音频文件
-(NSString *)audioFilePathWithUrl:(NSString*)url{
    if (url) {
        NSString *documentDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        NSString *filePath = [documentDir stringByAppendingPathComponent:[url lastPathComponent]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {//如果文件存在的话就重新删除并创建新的文件
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        NSLog(@"歌曲文件名为:%@, 本地文件路径:%@",[url lastPathComponent],filePath);
        return filePath;
    }
    return nil;
}

#pragma mark -- 网络音乐下载
-(void)downloadAudio{

    if (!self.audioUrl) {
        NSLog(@"不能下载文件");
        return;
    }
    //创建文件handle
    self.audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];

    NSMutableURLRequest *downloadRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.audioUrl]];
    NSLog(@"开始下载音频文件url : %@",self.audioUrl);
    //设置cookies
    downloadRequest.HTTPMethod = @"GET";
    
    NSURLConnection *downloadConnect = [[NSURLConnection alloc] initWithRequest:downloadRequest delegate:self];
    [downloadConnect scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [downloadConnect setDelegateQueue:self.operationQueue];
    [downloadConnect start];
}

#pragma mark -- NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    NSLog(@"文件下载失败 ： %@",error);
    [self.audioFileHandle closeFile];
    if ([self.delegate respondsToSelector:@selector(downloadingError:)]) {
        [self.delegate downloadingError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    NSLog(@"完成文件下载。。。");
    //把数据写入文件
    [self.audioFileHandle closeFile];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    
    self.totalLength = response.expectedContentLength;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse*)response statusCode];
        NSLog(@"接收到响应。。状态码为:%ld",[(NSHTTPURLResponse*)response statusCode]);
        if(statusCode != 200){
            NSError *error = [NSError errorWithDomain:@"下载音频文件失败" code:statusCode userInfo:@{NSUnderlyingErrorKey:@"下载音频文件失败"}];
            if ([self.delegate respondsToSelector:@selector(downloadingError:)]) {
                [self.delegate downloadingError:error];
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    self.receiveLength += data.length;
//    NSLog(@"已下载数据长度: %lld, 总长度 : %lld",self.receiveLength,self.totalLength);
    [self.audioFileHandle writeData:data];
    [self.audioFileHandle seekToEndOfFile];
    float progress = 0;
    
    //调用进度更新
    if (self.totalLength > 0) {
        progress = (double)self.receiveLength/self.totalLength;
    }
    if ([self.delegate respondsToSelector:@selector(downloadingAudioProgress:receivedLength:totalLength:)]) {
        [self.delegate downloadingAudioProgress:progress receivedLength:self.receiveLength totalLength:self.totalLength];
    }
}

@end
