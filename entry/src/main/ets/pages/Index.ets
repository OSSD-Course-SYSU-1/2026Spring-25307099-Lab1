/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { LengthMetrics, window } from '@kit.ArkUI';
import { avSession } from '@kit.AVSessionKit';
import { VideoData } from '../module/VideoData';
import { VideoInfo } from '../module/VideoInfo';
import { WindowUtil } from '../utils/WindowUtil';
import { FormatTime } from '../utils/FotmatTime';
import { VolumeView } from '../view/VolumeView';
import { AVSessionController } from '../controller/AVSessionController';
import { SmallWidnowVideo } from '../view/SmallWidnowVideo';
import { VideoListPage } from '../view/VideoListPage';
import { VideoStatus } from '../constants/VideoStatus';
import CommonConstants from '../constants/CommonConstants';
import Logger from '../utils/Logger';

const TAG = '[IndexPage]';

// 弹幕数据结构
interface DanmuItem {
  id: number;
  text: string;
  offsetX: number;
  speed: number;
  color: string;
  fontSize: number;
  yPosition: number;
}

@Entry
@Component
struct Index {
  private screenHeight: number = 0;
  private screenWidth: number = 0;
  private windowUtil: WindowUtil = WindowUtil.getInstance();
  private videoController: VideoController = new VideoController();
  private avSessionController: AVSessionController = AVSessionController.getInstance();
  private timeoutID: number = 0;
  private animationId: number = 0;
  @State currentVideoStatus: string = 'init';
  @State videoSrc: Resource = $rawfile('mountaineer.mp4');
  @State isAutoPlay: boolean = false;
  @State currentVideoIndex: number = 0;
  @State isFullScreen: boolean = false;
  @State currentTime: number = 0;
  @State durationTime: number = 0;
  @State playbackSpeed: string = '1.0X';
  @State curRate: PlaybackSpeed = PlaybackSpeed.Speed_Forward_1_00_X;
  @State isMute: boolean = false;
  @State visible: boolean = false;
  @State showBrightness: boolean = false;
  @State currentBrightness: number = 50;
  @State volume: number = 5;
  @State curSource: VideoInfo | undefined = undefined;
  @State isPlaying: boolean = false;
  @State scrollVal: number = 0;
  @StorageLink('deviceWidth') deviceWidth: number = 0;
  @StorageLink('deviceHeight') deviceHeight: number = 0;
  // 弹幕相关
  @State danmuList: DanmuItem[] = [];
  @State inputDanmu: string = '';
  @State showDanmu: boolean = true;
  @State selectedColor: string = '#FFFFFF';
  @State selectedFontSize: number = 16;
  @State showColorPicker: boolean = false;
  @State showFontSizePicker: boolean = false;

  // 颜色选项
  private colorOptions: string[] = ['#FFFFFF', '#FF0000', '#00FF00', '#FFFF00', '#FF69B4', '#FFA500'];
  private colorNames: string[] = ['白色', '红色', '绿色', '黄色', '粉色', '橙色'];
  // 字体大小选项
  private fontSizeOptions: number[] = [14, 16, 18, 20];
  private fontSizeNames: string[] = ['小', '中', '大', '特大'];

  aboutToAppear(): void {
    this.curSource = VideoData[0];
    this.initializeLandscapeMode();
    this.WindowSizeChange();

    try {
      window.getLastWindow(this.getUIContext().getHostContext(), (err: BusinessError, data: window.Window) => {
        if (err.code) {
          Logger.error(TAG, `getLastWindow failed. code: ${err.code}, message: ${err.message}`);
          return;
        }
        this.screenHeight = data.getWindowProperties().windowRect.height;
        this.screenWidth = data.getWindowProperties().windowRect.width;
      })
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `getWindowProperties failed. code: ${err.code}, message: ${err.message}`);
    }
    this.timeoutID = setTimeout(() => {
      this.setAVSessionListener();
    }, 100);

    this.startDanmuAnimation();
  }

  aboutToDisappear() {
    clearTimeout(this.timeoutID);
    this.windowUtil.registerOffWindowSizeChange();
    this.avSessionController.unregisterSessionListener();
    if (this.animationId) {
      clearInterval(this.animationId);
    }
  }

  onPageShow() {
    this.sessionPlay();
  }

  onPageHide() {
    this.sessionPause();
  }

  onBackPress() {
    if (this.isFullScreen) {
      this.isFullScreen = false;
      this.windowUtil.setLandscapeMultiWindow(false);
      this.windowUtil.enableWindowSystemBar();
      this.windowUtil.setMainWindowOrientation(window.Orientation.USER_ROTATION_PORTRAIT);
      return true;
    } else {
      return false;
    }
  }

  initializeLandscapeMode() {
    if (this.deviceWidth > this.deviceHeight) {
      this.isFullScreen = true;
      this.windowUtil.disableWindowSystemBar();
    } else {
      this.isFullScreen = false;
      this.windowUtil.enableWindowSystemBar();
    }
  }

  WindowSizeChange() {
    this.windowUtil.registerOnWindowSizeChange((size) => {
      if (size.width > size.height) {
        this.isFullScreen = true;
        this.scrollVal = 0;
        this.windowUtil.disableWindowSystemBar();
      } else {
        this.isFullScreen = false;
        this.windowUtil.enableWindowSystemBar();
      }
    })
  }

  public async setAVSessionListener() {
    if (!this.avSessionController) {
      return;
    }
    try {
      this.avSessionController.getAVSession()?.on('play', () => this.sessionPlay());
      this.avSessionController.getAVSession()?.on('pause', () => this.sessionPause());
      this.avSessionController.getAVSession()?.on('seek', (msTime: number) => {
        this.sessionSeek(msTime);
      });
      this.avSessionController.getAVSession()?.on('setLoopMode', () => {
      });
      this.avSessionController.getAVSession()?.on('playPrevious', () => this.changePlayVideo(true));
      this.avSessionController.getAVSession()?.on('playNext', () => this.changePlayVideo(false));
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `Set AVSession listener failed. code: ${err.code}, message: ${err.message}`);
    }
  }

  sessionPlay() {
    if (this.curSource) {
      this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    }
    this.videoController.start();
    this.isPlaying = true;
    this.updateIsPlay();
  }

  sessionPause() {
    if (this.curSource) {
      this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    }
    this.videoController.pause();
    this.isPlaying = false;
    this.updateIsPlay();
  }

  sessionSeek(msTime: number) {
    if (this.curSource) {
      this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    }
    this.isPlaying = true;
    this.updateIsPlay();
    this.videoController.setCurrentTime(msTime / 1000, SeekMode.Accurate);
    this.videoController.start();
  }

  playNextVideo() {
    if (!VideoData.length) {
      return;
    }
    this.currentVideoIndex = (this.currentVideoIndex + 1) % VideoData.length;
    this.curSource = VideoData[this.currentVideoIndex];
    if (!this.curSource) {
      return;
    }
    this.videoSrc = this.curSource.videoSrc;
    this.videoController.stop();
    this.currentTime = 0;
    this.isPlaying = false;
    this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    this.currentVideoStatus = VideoStatus.PLAY_STARTED;
    this.updateIsPlay();
    this.videoController.start();
    this.isAutoPlay = true;
  }

  changePlayVideo(isPrevious: boolean) {
    if (!VideoData.length) {
      return;
    }
    if (isPrevious) {
      this.currentVideoIndex = (this.currentVideoIndex - 1 + VideoData.length) % VideoData.length;
    } else {
      this.currentVideoIndex = (this.currentVideoIndex + 1) % VideoData.length;
    }
    this.curSource = VideoData[this.currentVideoIndex];
    if (!this.curSource) {
      return;
    }
    this.videoSrc = this.curSource.videoSrc;
    this.videoController.stop();
    this.currentTime = 0;
    this.isPlaying = false;
    this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    this.currentVideoStatus = VideoStatus.PLAY_STARTED;
    this.updateIsPlay();
    this.videoController.start();
    this.isAutoPlay = true;
  }

  updateIsPlay() {
    this.avSessionController.setAVSessionPlayState({
      state: this.isPlaying ? avSession.PlaybackState.PLAYBACK_STATE_PLAY :
        avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: this.currentTime * 1000,
        updateTime: new Date().getTime()
      },
      duration: this.durationTime * 1000,
      speed: this.curRate
    })
  }

  startDanmuAnimation() {
    this.animationId = setInterval(() => {
      if (!this.showDanmu || this.danmuList.length === 0) return;

      const newList: DanmuItem[] = [];
      for (let i = 0; i < this.danmuList.length; i++) {
        const danmu = this.danmuList[i];
        const newOffsetX = danmu.offsetX - danmu.speed;
        if (newOffsetX > -300) {
          const updatedDanmu: DanmuItem = {
            id: danmu.id,
            text: danmu.text,
            offsetX: newOffsetX,
            speed: danmu.speed,
            color: danmu.color,
            fontSize: danmu.fontSize,
            yPosition: danmu.yPosition
          };
          newList.push(updatedDanmu);
        }
      }
      this.danmuList = newList;
    }, 16);
  }

  sendDanmu() {
    if (this.inputDanmu.trim() === '') return;

    const rowIndex = Math.floor(Math.random() * 5);
    const yOffset = 50 + rowIndex * 30;

    const newDanmu: DanmuItem = {
      id: Date.now(),
      text: this.inputDanmu,
      offsetX: this.screenWidth,
      speed: 3 + Math.random() * 4,
      color: this.selectedColor,
      fontSize: this.selectedFontSize,
      yPosition: yOffset
    };
    const newList: DanmuItem[] = [];
    for (let i = 0; i < this.danmuList.length; i++) {
      newList.push(this.danmuList[i]);
    }
    newList.push(newDanmu);
    this.danmuList = newList;
    this.inputDanmu = '';
  }

  @Builder
  SpeedMenu() {
    Menu() {
      MenuItem({ content: '2.0X' })
        .width('100%')
        .onClick(() => {
          this.playbackSpeed = '2.0X';
          this.curRate = PlaybackSpeed.Speed_Forward_2_00_X;
        })
      MenuItem({ content: '1.75X' })
        .width('100%')
        .onClick(() => {
          this.playbackSpeed = '1.75X';
          this.curRate = PlaybackSpeed.Speed_Forward_1_75_X;
        })
      MenuItem({ content: '1.25X' })
        .width('100%')
        .onClick(() => {
          this.playbackSpeed = '1.25X';
          this.curRate = PlaybackSpeed.Speed_Forward_1_25_X;
        })
      MenuItem({ content: '1.0X' })
        .width('100%')
        .onClick(() => {
          this.playbackSpeed = '1.0X';
          this.curRate = PlaybackSpeed.Speed_Forward_1_00_X;
        })
    }
    .width(80)
    .font({ size: 12 })
    .fontColor(Color.White)
    .backgroundColor('#ff202224')
  }

  @Builder
  VideoControllerBuilder() {
    Row({ space: 4 }) {
      Text(FormatTime.getTimesBySecond(this.currentTime))
        .fontSize(12)
        .fontColor(Color.White)
      Slider({
        value: this.currentTime,
        max: this.durationTime,
        step: 1
      })
        .width('40%')
        .trackColor($r('app.color.slider_color'))
        .onChange((value) => {
          this.videoController.setCurrentTime(value, SeekMode.Accurate);
        })
      Text(FormatTime.getTimesBySecond(this.durationTime))
        .fontSize(12)
        .fontColor(Color.White)

      Column() {
        Text(this.playbackSpeed)
          .fontSize(12)
          .fontColor(Color.White)
      }
      .width(48)
      .height(24)
      .padding(4)
      .border({ width: 2, color: Color.White, radius: 12 })
      .bindMenu(this.SpeedMenu)

      Image($r('app.media.fullscreen'))
        .width('24vp')
        .height('24vp')
        .onClick(() => {
          this.isFullScreen = !this.isFullScreen;
          if (this.isFullScreen) {
            this.windowUtil.setLandscapeMultiWindow(true);
            this.windowUtil.disableWindowSystemBar();
            this.windowUtil.setMainWindowOrientation(window.Orientation.USER_ROTATION_LANDSCAPE);
          }
        })

      Button('下一集')
        .fontSize(12)
        .height(24)
        .backgroundColor(Color.Blue)
        .onClick(() => {
          this.playNextVideo();
        })
    }
    .width('100%')
    .position({ y: 180 })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  FullScreenVideoControllerBuilder() {
    Row({ space: 8 }) {
      Text(FormatTime.getTimesBySecond(this.currentTime))
        .fontSize(12)
        .fontColor(Color.White)
      Slider({
        value: this.currentTime,
        max: this.durationTime,
        step: 1
      })
        .width('40%')
        .trackColor($r('app.color.slider_color'))
        .onChange((value) => {
          this.videoController.setCurrentTime(value, SeekMode.Accurate);
        })
      Text(FormatTime.getTimesBySecond(this.durationTime))
        .fontSize(12)
        .fontColor(Color.White)

      Column() {
        Text(this.playbackSpeed)
          .fontSize(12)
          .fontColor(Color.White)
      }
      .width(48)
      .height(24)
      .padding(4)
      .border({ width: 2, color: Color.White, radius: 12 })
      .bindMenu(this.SpeedMenu)

      Button(this.showDanmu ? '弹幕开' : '弹幕关')
        .fontSize(11)
        .height(24)
        .backgroundColor(this.showDanmu ? Color.Green : Color.Gray)
        .onClick(() => {
          this.showDanmu = !this.showDanmu;
        })

      Image(this.isMute || this.volume === 0.0 ? $r('app.media.mute') : $r('app.media.with_audio'))
        .width('20vp')
        .height('20vp')
        .onClick(() => {
          this.isMute = !this.isMute;
          if (this.isMute) {
            this.volume = 0.0;
          } else {
            this.volume = 0.5;
          }
        })

      Button('下一集')
        .fontSize(11)
        .height(24)
        .backgroundColor(Color.Blue)
        .onClick(() => {
          this.playNextVideo();
        })

      Image($r('app.media.reduce_fullscreen'))
        .width('20vp')
        .height('20vp')
        .onClick(() => {
          this.isFullScreen = !this.isFullScreen;
          if (!this.isFullScreen) {
            this.windowUtil.setLandscapeMultiWindow(false);
            this.windowUtil.enableWindowSystemBar();
            this.windowUtil.setMainWindowOrientation(window.Orientation.USER_ROTATION_PORTRAIT);
          }
        })
    }
    .width('100%')
    .height('40%')
    .position({ y: '73%' })
    .justifyContent(FlexAlign.Center)
  }

  private getValidValue(inputVal: number, minVal: number, maxVal: number): number {
    inputVal = Math.min(inputVal, maxVal);
    inputVal = Math.max(inputVal, minVal);
    return inputVal;
  }

  @Builder
  ColorPickerBuilder() {
    Column() {
      Text('选择弹幕颜色')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      Row() {
        ForEach(this.colorOptions, (color: string, index: number) => {
          Column() {
            Circle({ width: 36, height: 36 })
              .fill(color)
              .margin({ bottom: 4 })
            Text(this.colorNames[index])
              .fontSize(11)
          }
          .onClick(() => {
            this.selectedColor = color;
            this.showColorPicker = false;
          })
          .margin({ left: 6, right: 6 })
        })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')

      Divider().margin({ top: 12, bottom: 12 })

      Button('取消')
        .onClick(() => {
          this.showColorPicker = false;
        })
        .width('100%')
        .height(32)
        .fontSize(13)
        .backgroundColor('#f0f0f0')
        .fontColor('#666666')
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .width('85%')
  }

  @Builder
  FontSizePickerBuilder() {
    Column() {
      Text('选择弹幕大小')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      Row() {
        ForEach(this.fontSizeOptions, (size: number, index: number) => {
          Column() {
            Text(`${size}`)
              .fontSize(size)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 4 })
            Text(this.fontSizeNames[index])
              .fontSize(11)
              .fontColor(this.selectedFontSize === size ? '#007AFF' : '#666666')
          }
          .width(50)
          .padding({ top: 8, bottom: 8 })
          .borderRadius(10)
          .backgroundColor(this.selectedFontSize === size ? '#e8f4ff' : '#f5f5f5')
          .onClick(() => {
            this.selectedFontSize = size;
            this.showFontSizePicker = false;
          })
          .margin({ left: 4, right: 4 })
        })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')

      Divider().margin({ top: 12, bottom: 12 })

      Button('取消')
        .onClick(() => {
          this.showFontSizePicker = false;
        })
        .width('100%')
        .height(32)
        .fontSize(13)
        .backgroundColor('#f0f0f0')
        .fontColor('#666666')
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .width('85%')
  }

  build() {
    Stack() {
      Column() {
        Scroll() {
          Column({ space: CommonConstants.COMPONENT_SPACE }) {
            Stack() {
              Video({
                src: this.videoSrc,
                controller: this.videoController,
                currentProgressRate: this.curRate,
                posterOptions: { showFirstFrame: true }
              })
                .width(this.isFullScreen ? '80%' : '100%')
                .height(this.isFullScreen ? '100%' : 220)
                .muted(this.isMute)
                .autoPlay(this.isAutoPlay)
                .loop(true)
                .controls(false)
                .onPrepared((event) => {
                  this.currentVideoStatus = VideoStatus.PLAY_PREPARED;
                  if (event) {
                    this.durationTime = event.duration;
                    if (this.curSource) {
                      this.avSessionController.setAVMetadata(this.curSource, event.duration * 1000);
                    }
                  }
                })
                .onStart(() => {
                  this.isPlaying = true;
                  this.currentVideoStatus = VideoStatus.PLAY_STARTED;
                  this.updateIsPlay();
                })
                .onPause(() => {
                  this.currentVideoStatus = VideoStatus.PLAY_PAUSED;
                  this.updateIsPlay();
                })
                .onFinish(() => {
                  this.currentVideoStatus = VideoStatus.PLAY_FINISHED;
                })
                .onStop(() => {
                  this.currentVideoStatus = VideoStatus.PLAY_STOPPED;
                })
                .onUpdate((event) => {
                  if (event) {
                    this.currentTime = event.time;
                    this.updateIsPlay();
                  }
                })

              if (this.showDanmu && this.danmuList.length > 0) {
                ForEach(this.danmuList, (danmu: DanmuItem) => {
                  Text(danmu.text)
                    .fontSize(danmu.fontSize)
                    .fontColor(danmu.color)
                    .fontWeight(FontWeight.Bold)
                    .shadow({ radius: 2, color: '#000000' })
                    .padding({ left: 8, right: 8 })
                    .position({ x: danmu.offsetX, y: danmu.yPosition })
                })
              }

              if (this.isFullScreen) {
                Stack() {
                  VolumeView({
                    visible: this.visible,
                    volume: this.volume,
                  })
                  if (this.showBrightness) {
                    Column() {
                      Text(`亮度: ${Math.round(this.currentBrightness)}%`)
                        .fontSize(16)
                        .fontColor(Color.White)
                        .backgroundColor('rgba(0,0,0,0.6)')
                        .padding(10)
                        .borderRadius(8)
                    }
                    .position({ x: '50%', y: '50%' })
                    .translate({ x: '-50%', y: '-50%' })
                  }
                  this.FullScreenVideoControllerBuilder();
                }
                .gesture(
                  GestureGroup(
                    GestureMode.Exclusive,
                    PanGesture({ direction: PanDirection.Vertical })
                      .onActionUpdate((event: GestureEvent) => {
                        let currentX: number = 0;
                        if (event.fingerList && event.fingerList.length > 0) {
                          currentX = event.fingerList[0].localX;
                        }
                        const isRightSide = currentX > (this.screenWidth / 2);
                        if (isRightSide && this.screenWidth > 0) {
                          this.showBrightness = true;
                          let deltaBrightness = -event.offsetY / this.screenHeight * 100;
                          let newBrightness = this.currentBrightness + deltaBrightness;
                          newBrightness = Math.max(0, Math.min(100, newBrightness));
                          this.currentBrightness = newBrightness;
                        } else {
                          this.visible = true;
                          let curVolume = this.volume - event.offsetY / this.screenHeight * 10;
                          curVolume = Math.max(0, Math.min(CommonConstants.MAX_VOLUME, curVolume));
                          this.volume = curVolume;
                          this.isMute = (curVolume === 0);
                        }
                      })
                      .onActionEnd(() => {
                        this.visible = false;
                        this.showBrightness = false;
                      }),
                    LongPressGesture({ repeat: true })
                      .onAction(() => {
                        this.playbackSpeed = '2.0X';
                        this.curRate = PlaybackSpeed.Speed_Forward_2_00_X;
                      })
                      .onActionEnd(() => {
                        this.playbackSpeed = '1.0X';
                        this.curRate = PlaybackSpeed.Speed_Forward_1_00_X;
                      })
                  )
                )
              } else {
                this.VideoControllerBuilder();
              }

              if (this.currentVideoStatus !== VideoStatus.PLAY_STARTED) {
                Image($r('app.media.play_pause'))
                  .width(36)
              }
            }
            .onClick(() => {
              if (this.currentVideoStatus === VideoStatus.PLAY_STARTED) {
                this.videoController.pause();
                this.isPlaying = false;
                this.updateIsPlay();
              } else {
                this.videoController.start();
                this.isPlaying = true;
                this.updateIsPlay();
              }
            })
            .gesture(
              LongPressGesture({ repeat: true })
                .onAction(() => {
                  this.playbackSpeed = '2.0X';
                  this.curRate = PlaybackSpeed.Speed_Forward_2_00_X;
                })
                .onActionEnd(() => {
                  this.playbackSpeed = '1.0X';
                  this.curRate = PlaybackSpeed.Speed_Forward_1_00_X;
                })
            )

            // 弹幕发送区域（非全屏）
            if (!this.isFullScreen) {
              Column() {
                Row() {
                  TextInput({ placeholder: '发条弹幕吧...', text: this.inputDanmu })
                    .onChange((value: string) => {
                      this.inputDanmu = value;
                    })
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor('#f5f5f5')
                    .borderRadius(18)
                    .padding({ left: 16, right: 16 })
                    .fontSize(14)
                    .fontColor(Color.Black)
                    .placeholderColor('#999999')

                  Button('发送')
                    .fontSize(13)
                    .height(36)
                    .padding({ left: 16, right: 16 })
                    .backgroundColor('#007AFF')
                    .fontColor(Color.White)
                    .borderRadius(18)
                    .onClick(() => {
                      this.sendDanmu();
                    })
                    .margin({ left: 10 })
                }
                .width('100%')

                Row() {
                  Button('颜色')
                    .fontSize(13)
                    .height(34)
                    .padding({ left: 20, right: 20 })
                    .backgroundColor('#f0f0f0')
                    .fontColor('#333333')
                    .borderRadius(17)
                    .onClick(() => {
                      this.showColorPicker = true;
                    })

                  Button('字体大小')
                    .fontSize(13)
                    .height(34)
                    .padding({ left: 20, right: 20 })
                    .backgroundColor('#f0f0f0')
                    .fontColor('#333333')
                    .borderRadius(17)
                    .onClick(() => {
                      this.showFontSizePicker = true;
                    })

                  Button(this.showDanmu ? '弹幕开' : '弹幕关')
                    .fontSize(13)
                    .height(34)
                    .padding({ left: 20, right: 20 })
                    .backgroundColor(this.showDanmu ? '#34C759' : '#f0f0f0')
                    .fontColor(this.showDanmu ? Color.White : '#333333')
                    .borderRadius(17)
                    .onClick(() => {
                      this.showDanmu = !this.showDanmu;
                    })
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceEvenly)
                .margin({ top: 8 })
              }
              .width('95%')
              .margin({ top: 10, bottom: 10 })
              .padding({ left: 8, right: 8 })
            }

            if (!this.isFullScreen) {
              VideoListPage({
                currentVideoIndex: this.currentVideoIndex,
                videoSrc: this.videoSrc,
                isAutoPlay: this.isAutoPlay,
                curSource: this.curSource
              })
            }
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onWillScroll((_xOffset: number, yOffset: number) => {
          this.scrollVal += yOffset;
        })

        if (this.scrollVal >= 240 && this.isPlaying && !this.isFullScreen) {
          SmallWidnowVideo({
            videoSrc: this.videoSrc,
            curRate: this.curRate,
            isMute: this.isMute,
            currentTime: this.currentTime,
            isPlaying: this.isPlaying,
            videoController: this.videoController
          })
        }
      }
      .width('100%')
      .height('100%')

      if (this.showColorPicker) {
        Column() {
          this.ColorPickerBuilder()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.showColorPicker = false;
        })
      }

      if (this.showFontSizePicker) {
        Column() {
          this.FontSizePickerBuilder()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.showFontSizePicker = false;
        })
      }
    }
  }
}
