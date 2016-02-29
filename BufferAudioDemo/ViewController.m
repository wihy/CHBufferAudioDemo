//
//  ViewController.m
//  BufferAudioDemo
//
//  Created by chunhaixu on 16/2/26.
//  Copyright © 2016年 SL. All rights reserved.
//

#import "ViewController.h"
#import "CHBufferAudioManager.h"

@interface ViewController ()<CHBufferAudioManagerDelegate>

@property(nonatomic,strong) CHBufferAudioManager *bufferAudioManager;


@property(nonatomic,weak) IBOutlet UIProgressView *progressView;
@property(nonatomic,weak) IBOutlet UILabel *errorLabel;
@property(nonatomic,weak) IBOutlet UILabel *bufferingLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //测试用网易云音乐下载地址需要配置鉴权
    NSString *mp3Url = @"http://m8.music.126.net/20160229144300/c55db5136620f98c443a64d28993c727/ymusic/0c7a/0f7a/af09/07428e57fccd1e064e8d7afa30757573.mp3";
    self.bufferAudioManager = [CHBufferAudioManager bufferManagerWithAudioUrl:mp3Url];
    self.bufferAudioManager.delegate = self;
}


-(IBAction)startBuffer:(id)sender{
    self.errorLabel.text = @"";
    [self.bufferAudioManager startBuffering];
}

-(IBAction)stopBuffer:(id)sender{
    self.errorLabel.text = @"";
     [self.bufferAudioManager stopBuffering];
}

#pragma mark --
-(void)audioBufferingProgress:(float)progress receivedLength:(long long)receive totalLength:(long long)total{
    self.progressView.progress = progress;
    self.bufferingLabel.text = [NSString stringWithFormat:@"下载进度: %lld/%lld (%.1f)",receive,total,progress];
}
-(void)audioBufferDidFailed:(NSError*)error{
    self.errorLabel.text = [error domain];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
