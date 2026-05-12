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

@Entry
@Component
struct Index {
  private screenHeight: number = 0; // Screen height.
  private screenWidth: number = 0; // Screen width.
  private windowUtil: WindowUtil = WindowUtil.getInstance();
  private videoController: VideoController = new VideoController();
  private avSessionController: AVSessionController = AVSessionController.getInstance();
  private timeoutID: number = 0;
  @State currentVideoStatus: string = 'init';
  @State videoSrc: Resource = $rawfile('mountaineer.mp4');
  @State isAutoPlay: boolean = false; // Whether to play automatically.
  @State currentVideoIndex: number = 0;
  @State isFullScreen: boolean = false; // Whether to play in full screen.
  @State currentTime: number = 0; // Initialize the current time to 0.
  @State durationTime: number = 0; // Initialize the total video duration to 0.
  @State playbackSpeed: string = '1.0X';
  // [Start playback_speed]
  @State curRate: PlaybackSpeed = PlaybackSpeed.Speed_Forward_1_00_X; // Playback speed.
  // [End playback_speed]
  @State isMute: boolean = false; // Play with mute or not.
  @State visible: boolean = false; // Whether to display the brightness adjustment icon and slider.
  @State showBrightness: boolean = false; // 是否显示亮度调节提示
  @State currentBrightness: number = 50; // 亮度值 0-100
  @State volume: number = 5;
  @State curSource: VideoInfo | undefined = undefined;
  @State isPlaying: boolean = false;
  @State scrollVal: number = 0;
  @StorageLink('deviceWidth') deviceWidth: number = 0;
  @StorageLink('deviceHeight') deviceHeight: number = 0;
  // 循环播放开关
  @State isLoopPlay: boolean = true;

  aboutToAppear(): void {
    // 修复：取数组的第一个元素，而不是整个数组
    this.curSource = VideoData[0];
    this.initializeLandscapeMode();
    this.WindowSizeChange();

    try {
      // Get the width and height of the window.
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
  }

  aboutToDisappear() {
    clearTimeout(this.timeoutID);
    this.windowUtil.registerOffWindowSizeChange();
    this.avSessionController.unregisterSessionListener();
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

  // Initialize landscape mode.
  initializeLandscapeMode() {
    if (this.deviceWidth > this.deviceHeight) {
      this.isFullScreen = true;
      this.windowUtil.disableWindowSystemBar();
    } else {
      this.isFullScreen = false;
      this.windowUtil.enableWindowSystemBar();
    }
  }

  // Change in registration window size.
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

  // [Start set_AVSession_listener]
  // Set AVSession to listen.
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
  // [End set_AVSession_listener]

  // AVSession video playback.
  sessionPlay() {
    if (this.curSource) {
      this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    }
    this.videoController.start();
    this.isPlaying = true;
    this.updateIsPlay();
  }

  // AVSession video paused.
  sessionPause() {
    if (this.curSource) {
      this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    }
    this.videoController.pause();
    this.isPlaying = false;
    this.updateIsPlay();
  }

  // AVSession video jump playback.
  sessionSeek(msTime: number) {
    if (this.curSource) {
      this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    }
    this.isPlaying = true;
    this.updateIsPlay();
    this.videoController.setCurrentTime(msTime / 1000, SeekMode.Accurate);
    this.videoController.start();
  }

  // 跳转到下一个视频
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

  // AVSession switches to the previous/next video.
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

    // Stop the current playback and reset the status.
    this.videoController.stop();
    this.currentTime = 0;
    this.isPlaying = false;

    // Update metadata.
    this.avSessionController.setAVMetadata(this.curSource, this.durationTime * 1000);
    this.currentVideoStatus = VideoStatus.PLAY_STARTED;
    this.updateIsPlay();
    this.videoController.start();
    this.isAutoPlay = true;
  }

  // [Start update_play_status]
  // Update AVSession playback status.
  updateIsPlay() {
    this.avSessionController.setAVSessionPlayState({
      state: this.isPlaying ? avSession.PlaybackState.PLAYBACK_STATE_PLAY :
        avSession.PlaybackState.PLAYBACK_STATE_PAUSE, // Playback status.
      position: {
        elapsedTime: this.currentTime * 1000, // Elapsed time.
        updateTime: new Date().getTime() // Update time.
      },
      duration: this.durationTime * 1000, // The duration of current media resources.
      speed: this.curRate
    })
  }
  // [End update_play_status]

  // [Start speed_menu]
  // Playback speed setting.
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
    // [StartExclude speed_menu]
    .width(80)
    .font({
      size: 12
    })
    .fontColor(Color.White)
    .menuItemDivider({
      strokeWidth: LengthMetrics.vp(0.5),
      color: '#d5d5d5',
      mode: DividerMode.EMBEDDED_IN_MENU
    })
    .backgroundColor('#ff202224')
    // [EndExclude speed_menu]
  }
  // [End speed_menu]

  // Non-full screen playback.
  @Builder
  VideoControllerBuilder() {
    Row({ space: 4 }) {
      Text(FormatTime.getTimesBySecond(this.currentTime))
        .fontSize(12)
        .fontColor(Color.White)
      // [Start seek_play_video]
      Slider({
        value: this.currentTime,
        max: this.durationTime,
        step: 1
      })
      // [StartExclude seek_play_video]
        .width('40%')
        .trackColor($r('app.color.slider_color'))
        // [EndExclude seek_play_video]
        .onChange((value) => {
          this.videoController.setCurrentTime(value, SeekMode.Accurate);
        })
      // [End seek_play_video]
      Text(FormatTime.getTimesBySecond(this.durationTime))
        .fontSize(12)
        .fontColor(Color.White)

      // 1. 倍速按钮
      Column() {
        Text(this.playbackSpeed)
          .fontSize(12)
          .fontColor(Color.White)
      }
      .width(48)
      .height(24)
      .padding(4)
      .border({
        width: 2,
        color: Color.White,
        radius: 12
      })
      .bindMenu(this.SpeedMenu)

      // 2. 全屏按钮（倍速右边）
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

      // 3. 下一集按钮（全屏右边）
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

  // Full screen playback.
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
        .width('45%')
        .trackColor($r('app.color.slider_color'))
        .onChange((value) => {
          this.videoController.setCurrentTime(value, SeekMode.Accurate);
        })
      Text(FormatTime.getTimesBySecond(this.durationTime))
        .fontSize(12)
        .fontColor(Color.White)

      // 倍速按钮
      Column() {
        Text(this.playbackSpeed)
          .fontSize(12)
          .fontColor(Color.White)
      }
      .width(48)
      .height(24)
      .padding(4)
      .border({
        width: 2,
        color: Color.White,
        radius: 12
      })
      .bindMenu(this.SpeedMenu)

      // 循环播放按钮
      Button(this.isLoopPlay ? '循环' : '单次')
        .fontSize(11)
        .height(24)
        .backgroundColor(this.isLoopPlay ? Color.Green : Color.Gray)
        .onClick(() => {
          this.isLoopPlay = !this.isLoopPlay;
        })

      // 静音按钮
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

      // 下一集按钮
      Button('下一集')
        .fontSize(11)
        .height(24)
        .backgroundColor(Color.Blue)
        .onClick(() => {
          this.playNextVideo();
        })

      // 退出全屏按钮
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

  // Range limit for input values.
  private getValidValue(inputVal: number, minVal: number, maxVal: number): number {
    inputVal = Math.min(inputVal, maxVal);
    inputVal = Math.max(inputVal, minVal);
    return inputVal;
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: CommonConstants.COMPONENT_SPACE }) {
          Stack() {
            Video({
              src: this.videoSrc,
              controller: this.videoController,
              currentProgressRate: this.curRate,
              posterOptions: {
                showFirstFrame: true,
              }
            })
              .width(this.isFullScreen ? '80%' : '100%')
              .height(this.isFullScreen ? '100%' : 220)
              .muted(this.isMute)
              .autoPlay(this.isAutoPlay)
              .loop(this.isLoopPlay)
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

          if (!this.isFullScreen) {
            VideoListPage({
              currentVideoIndex: this.currentVideoIndex,
              videoSrc: this.videoSrc,
              isAutoPlay: this.isAutoPlay,
              curSource: this.curSource,
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
          videoController: this.videoController,
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
