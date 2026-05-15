# 基于Video组件播放长视频 - 个性化增强版

### 项目简介

本示例基于Video组件实现了播放长视频功能，指导开发者如何通过Video组件实现长视频播放，如：基础播控、视频首帧显示、自定义播放进度条、前台小窗播放、循环播放、视频全屏播放、视频音量设置、静音播放、长按倍速播放、点击选择倍速播放、接入播控中心等功能场景。

**本版本在原有基础上进行了以下个性化增强：**
- ✅ 非全屏模式下增加倍速按钮，方便快速调速
- ✅ 全屏模式下增加循环播放开关
- ✅ 增加下一集按钮，支持快速切换视频
- ✅ 屏幕右侧上下滑动调节亮度
- ✅ 非全屏模式支持长按倍速

### 使用说明

1. 安装进入应用。
2. 点击视频区域播放/暂停播放本地视频，并可通过点击视频列表内容切换视频。
3. 点击Slider实现视频跳转播放。
4. 点击全屏按钮，进入全屏播放。
5. 进入全屏后：
   - 滑动视频**左侧区域**，实现音量调节
   - 滑动视频**右侧区域**，实现亮度调节（**新增**）
   - 点击播放速度按钮，选择视频播放倍速
   - 点击**循环按钮**，切换循环播放模式（**新增**）
   - 点击**下一集按钮**，快速切换视频（**新增**）
   - 长按视频区域，实现2.0倍速临时加速
   - 点击静音按钮，实现静音播放
6. 非全屏模式下：
   - 控制栏新增**倍速按钮**，可快速选择播放速度（**新增**）
   - 控制栏新增**下一集按钮**，快速切换视频（**新增**）
   - 长按视频区域同样支持2.0倍速临时加速（**新增**）
7. 视频播放时，通过播控中心控制视频的播放、暂停、跳转播放、播放上一个/下一个视频。

### 工程分析

video-show-master/
│
├── AppScope/                              # 【应用级配置】整个App的全局设置
│   ├── resources/
│   │   └── base/
│   │       ├── element/
│   │       │   └── string.json           # 字符串资源（应用名称、按钮文字等）
│   │       └── media/
│   │           └── app_icon.png          # 应用桌面图标
│   └── app.json5                         # 应用配置文件（包名、版本号、SDK版本）
│
├── entry/                                 # 【主模块】所有核心功能代码
│   ├── src/
│   │   └── main/
│   │       ├── ets/                      # 【源代码目录】程序员写的代码
│   │       │   ├── constants/            # 【常量层】存放固定不变的值
│   │       │   │   ├── CommonConstants.ets   # 通用常量（最大音量15、滑动阈值等）
│   │       │   │   └── VideoStatus.ets       # 视频状态（准备中/播放中/暂停/结束）
│   │       │   ├── controller/           # 【控制器层】业务逻辑处理
│   │       │   │   └── AVSessionController.ets  # 播控中心控制器
│   │       │   ├── entryability/         # 【应用入口层】App启动入口
│   │       │   │   └── EntryAbility.ets       # Ability生命周期管理
│   │       │   ├── entrybackupability/   # 【备份恢复层】数据备份
│   │       │   │   └── EntryBackupAbility.ets # 备份恢复功能
│   │       │   ├── module/               # 【数据模型层】定义数据结构
│   │       │   │   ├── VideoData.ets          # 视频数据源（具体的视频列表）
│   │       │   │   └── VideoInfo.ets          # 视频信息定义（标题、封面、视频文件）
│   │       │   ├── pages/                # 【页面层】用户看到的界面
│   │       │   │   └── Index.ets              # 主播放页面（核心文件，已修改）
│   │       │   ├── utils/                # 【工具层】辅助功能函数
│   │       │   │   ├── BackgroundTaskManager.ets  # 后台任务管理
│   │       │   │   ├── FormatTime.ets            # 时间格式化（秒转mm:ss）
│   │       │   │   ├── Logger.ets                # 日志记录（调试用）
│   │       │   │   └── WindowUtil.ets            # 窗口管理（横竖屏切换）
│   │       │   └── view/                 # 【组件层】可复用的UI组件
│   │       │       ├── SmallWidnowVideo.ets     # 小窗播放组件
│   │       │       ├── VideoListPage.ets        # 视频列表组件
│   │       │       └── VolumeView.ets           # 音量调节滑块组件
│   │       ├── resources/                # 【资源目录】图片、文字、视频文件
│   │       │   ├── base/                # 基础资源（默认语言/主题）
│   │       │   │   ├── element/         # 文本资源（string.json）
│   │       │   │   ├── media/           # 图片资源（图标、背景图）
│   │       │   │   └── profile/         # 配置文件（页面路由）
│   │       │   ├── en_US/               # 英文本地化资源
│   │       │   ├── zh_CN/               # 中文本地化资源
│   │       │   ├── dark/                # 深色主题资源
│   │       │   └── rawfile/             # 原始文件（不编译直接打包）
│   │       │       └── mountaineer.mp4  # 示例视频文件
│   │       └── module.json5             # 【模块配置】模块信息配置
│   ├── build-profile.json5              # 【模块构建配置】编译设置
│   ├── hvigorfile.ts                    # 【模块构建脚本】打包脚本
│   └── oh-package.json5                 # 【模块依赖】第三方库依赖
│
├── hvigor/                              # 【构建工具配置】Hvigor打包工具设置
│   └── hvigor-config.json5
│
├── screenshots/                         # 【截图目录】用于README文档展示
│   └── device/
│       ├── avSession.png                # 播控中心截图
│       ├── homePage.png                 # 首页截图
│       ├── smallVideo.png               # 小窗播放截图
│       └── volume.png                   # 音量调节截图
│
├── build-profile.json5                  # 【项目构建配置】全局编译设置
├── code-linter.json5                    # 【代码检查】ArkTS语法规范检查
├── hvigorfile.ts                        # 【项目构建脚本】主打包脚本
├── oh-package.json5                     # 【项目依赖】第三方库依赖
├── LICENSE                              # 【开源许可证】Apache 2.0
├── OAT.xml                              # 【开源审核】开源代码合规配置
└── README.md                            # 【项目说明】项目介绍文档


### 具体实现

**原有功能：**

- Video 组件：核心播放器，通过 currentProgressRate 控制倍速，loop 属性控制循环播放。
- 手势识别：PanGesture 实现左侧滑动调节音量。
- 状态管理：@State 装饰器管理播放状态、时间、倍速等，状态变化自动刷新 UI。
- 窗口管理：WindowUtil 封装横竖屏切换和系统状态栏控制。
- 播控中心：AVSession 将播放器接入系统控制中心。
- 组件复用：@Builder 构建倍速菜单，自定义组件实现音量滑块和小窗播放。

**本次新增功能：**

#### 1. 非全屏倍速按钮

在非全屏控制栏中添加倍速按钮，点击弹出倍速菜单（0.75x、1.0x、1.25x、1.5x、1.75x、2.0x）。

```typescript
// 倍速按钮
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

2. 循环播放开关
在全屏控制栏中添加循环播放按钮，点击切换循环模式，按钮颜色随状态变化（绿色=循环开，灰色=循环关）。

// 循环播放按钮
Button(this.isLoopPlay ? '循环' : '单次')
  .fontSize(11)
  .height(24)
  .backgroundColor(this.isLoopPlay ? Color.Green : Color.Gray)
  .onClick(() => {
    this.isLoopPlay = !this.isLoopPlay;
  })

// Video组件绑定循环属性
Video({ ... })
  .loop(this.isLoopPlay)

3. 下一集按钮
在全屏和非全屏控制栏中添加"下一集"按钮，点击切换到视频列表中的下一个视频。

// 跳转到下一个视频
playNextVideo() {
  this.currentVideoIndex = (this.currentVideoIndex + 1) % VideoData.length;
  this.curSource = VideoData[this.currentVideoIndex];
  this.videoSrc = this.curSource.videoSrc;
  this.videoController.stop();
  this.videoController.start();
}

4. 屏幕亮度调节（右侧滑动）
在全屏模式下，屏幕右侧上下滑动调节亮度，并显示亮度百分比提示。

// 判断滑动区域
const isRightSide = currentX > (this.screenWidth / 2);
if (isRightSide) {
  this.showBrightness = true;
  let deltaBrightness = -event.offsetY / this.screenHeight * 100;
  let newBrightness = this.currentBrightness + deltaBrightness;
  newBrightness = Math.max(0, Math.min(100, newBrightness));
  this.currentBrightness = newBrightness;
}

5. 非全屏长按倍速
非全屏模式下，长按视频区域同样支持临时2.0倍速播放，松手后恢复原速。

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
