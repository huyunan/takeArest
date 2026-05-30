import { preferences } from '@kit.ArkData';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { formatDuration, formatDuration2, PRESETS, PREFS_NAME, RestData } from '../common/utils';

@Entry
@Component
struct Index {
  // 状态变量
  @State now: Date = new Date();
  @State filterEnabled: boolean = true;
  @State startupEnabled: boolean = false;
  @State restEnabled: boolean = true;
  @State autoKeyEnabled: boolean = true;
  @State filterStrength: number = 30;
  @State colorTemp: number = 4700;
  @State restMinutes: number = 60;
  @State restDuration: number = 3;
  @State restTimes: number = 0;
  @State preRestTimes: number = 0;
  @State activePreset: string = '智能';
  @State nextRestAt: Date | null = null;
  @State restEndAt: Date | null = null;

  private prefs: preferences.Preferences | null = null;
  private timeTimerId: number = -1;
  private restTimerId: number = -1;

  // 计算属性：是否白天
  get isDaytime(): boolean {
    return this.now.getHours() >= 6 && this.now.getHours() < 18;
  }

  // 计算属性：下次休息倒计时
  get nextRestCountdown(): string {
    if (this.restEnabled && this.nextRestAt) {
      const diff = (this.nextRestAt.getTime() - this.now.getTime()) / 1000;
      return formatDuration(diff);
    }
    return '已暂停';
  }

  // 计算属性：当前时间文本
  get timeText(): string {
    return this.now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  }

  // 计算属性：当前日期文本
  get dateText(): string {
    return this.now.toLocaleDateString('zh-CN', { month: 'long', day: 'numeric', weekday: 'short' });
  }

  aboutToAppear() {
    this.initPreferences();
    this.startTimers();
  }

  onDisappear() {
    this.clearTimers();
  }

  // 初始化数据持久化
  private async initPreferences() {
    try {
      this.prefs = await preferences.getPreferences(getContext(this), PREFS_NAME);
      await this.loadAllPrefs();
    } catch (err) {
      const e = err as BusinessError;
      console.error(`Prefs init failed: ${e.code}, ${e.message}`);
    }
  }

  // 加载所有配置
  private async loadAllPrefs() {
    if (!this.prefs) return;

    // 加载基础配置
    this.startupEnabled = await this.prefs.get('startupEnabled', false) as boolean;
    this.filterEnabled = await this.prefs.get('filterEnabled', true) as boolean;
    this.restEnabled = await this.prefs.get('restEnabled', true) as boolean;
    this.autoKeyEnabled = await this.prefs.get('autoKeyEnabled', true) as boolean;
    this.activePreset = await this.prefs.get('preset', '智能') as string;
    this.restMinutes = await this.prefs.get('restMinutes', 60) as number;
    this.restDuration = await this.prefs.get('restDuration', 3) as number;

    // 加载自设参数
    if (this.activePreset === '自设') {
      this.filterStrength = await this.prefs.get('filterStrength', 30) as number;
      this.colorTemp = await this.prefs.get('colorTemp', 4700) as number;
    } else {
      this.applyPreset(this.activePreset);
    }

    // 加载休息次数
    await this.loadRestTimes();

    // 初始化下次休息时间
    if (this.restEnabled) this.nextRestAt = this.getNextRestTime();
  }

  // 加载休息次数
  private async loadRestTimes() {
    if (!this.prefs) return;
    const stored = await this.prefs.get('restTimes', '{}') as string;
    const today: string = new Date().getDate().toString();
    const yesterday = new Date(Date.now() - 86400000).getDate().toString();
    let data: Record<string, RestData> = {};
    data[today] = { times: 0 }
    data[yesterday] = { times: 0 }

    try { data = JSON.parse(stored); } catch (e) {}
    this.restTimes = data[today]?.times || 0;
    this.preRestTimes = data[yesterday]?.times || 0;
  }

  // 启动定时器
  private startTimers() {
    // 更新当前时间
    this.timeTimerId = setInterval(() => { this.now = new Date() }, 1000);
    // 检查休息时间
    this.restTimerId = setInterval(() => { this.checkRestTrigger() }, 1000);
  }

  // 清理定时器
  private clearTimers() {
    if (this.timeTimerId !== -1) clearInterval(this.timeTimerId);
    if (this.restTimerId !== -1) clearInterval(this.restTimerId);
  }

  // 应用预设
  private applyPreset(preset: string) {
    const config = PRESETS[preset];
    if (!config) return;
    const settings = preset === '智能' ? (this.isDaytime ? config.day : config.night) : config.day;
    this.filterStrength = settings.strength;
    this.colorTemp = settings.temp;
  }

  // 计算下次休息时间
  private getNextRestTime(): Date {
    return new Date(Date.now() + this.restMinutes * 60 * 1000);
  }

  // 计算休息结束时间
  private getRestEndTime(): Date {
    return new Date(Date.now() + this.restDuration * 60 * 1000);
  }

  // 检查是否触发休息
  private checkRestTrigger() {
    if (!this.restEnabled || !this.nextRestAt) return;
    if (this.now.getTime() >= this.nextRestAt.getTime()) {
      this.startRest();
    }
  }

  // 开始休息
  private startRest() {
    this.restEndAt = this.getRestEndTime();
    this.showLockWindow();
  }

  // 显示锁屏窗口（悬浮窗）
  private async showLockWindow() {
    try {
      // const win = await window.createWindow(getContext(this), {
      //   name: 'lock_window',
      //   windowType: window.WindowType.TYPE_FLOAT,
      //   ctx: getContext(this)
      // });
      // await win.setWindowLayoutFullScreen(true);
      // await win.loadContent('pages/LockScreen', { endAtMs: this.restEndAt?.getTime() || 0 });
      // await win.showWindow();
    } catch (err) {
      const e = err as BusinessError;
      console.error(`Lock window failed: ${e.code}, ${e.message}`);
    }
  }

  // 退出休息
  private async exitRest() {
    // 隐藏锁屏窗口
    try {
      const win = window.findWindow('lock_window');
      if (win) { await win.destroyWindow(); }
    } catch (e) {}

    // 重置休息时间
    this.restEndAt = null;
    if (this.restEnabled) {
      this.nextRestAt = this.getNextRestTime();
      await this.incrementRestTimes();
    }
  }

  // 增加今日休息次数
  private async incrementRestTimes() {
    if (!this.prefs) return;
    const hour = new Date().getHours();
    if (hour < 8) return; // 8点前不计入

    const today = new Date().getDate().toString();
    const stored = await this.prefs.get('restTimes', '{}') as string;
    const data: Record<string, RestData> = JSON.parse(stored);
    data[today] = { times: (data[today]?.times || 0) + 1 };
    this.restTimes = data[today].times;
    await this.prefs.put('restTimes', JSON.stringify(data));
    await this.prefs.flush();
  }

  // 切换过滤蓝光
  private async toggleFilter(val: boolean) {
    this.filterEnabled = val;
    if (this.prefs) {
      await this.prefs.put('filterEnabled', val);
      await this.prefs.flush();
    }
    // ⚠️ 系统无直接蓝光过滤API，需通过NAPI调用底层图形能力实现
    console.log(`Filter ${val ? 'enabled' : 'disabled'}, strength: ${this.filterStrength}, temp: ${this.colorTemp}`);
  }

  // 切换休息开关
  private async toggleRest(val: boolean) {
    this.restEnabled = val;
    this.nextRestAt = val ? this.getNextRestTime() : null;
    if (this.prefs) {
      await this.prefs.put('restEnabled', val);
      await this.prefs.flush();
    }
  }

  // 切换预设
  private async switchPreset(preset: string) {
    this.activePreset = preset;
    this.applyPreset(preset);
    if (this.prefs) {
      await this.prefs.put('preset', preset);
      if (preset === '自设') {
        await this.prefs.put('filterStrength', this.filterStrength);
        await this.prefs.put('colorTemp', this.colorTemp);
      }
      await this.prefs.flush();
    }
  }

  // 切换开机自启
  private async toggleStartup(val: boolean) {
    this.startupEnabled = val;
    try {
      // await autoLaunchManager.setAutoLaunch({
      //   bundleName: getContext(this).applicationInfo.name,
      //   abilityName: 'EntryAbility',
      //   enable: val
      // });
    } catch (err) {
      const e = err as BusinessError;
      console.error(`Auto launch failed: ${e.code}, ${e.message}`);
    }
    if (this.prefs) {
      await this.prefs.put('startupEnabled', val);
      await this.prefs.flush();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 背景
      Column() {}.width('100%').height('100%').backgroundColor('#F5F7FA')

      // 顶部栏
      Row() {
        Column() {
          Text('护眼吧').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#182431')
          Text('清醒护眼 · 专注节奏').fontSize(12).fontColor('#86909C').margin({ top: 2 })
        }
        Blank()
        Row() {
          Text(this.timeText).fontSize(16).fontColor('#182431')
          Text(this.dateText).fontSize(12).fontColor('#86909C').margin({ left: 8 })
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 4, color: '#1F000000', offsetY: 2 })
      .zIndex(1)

      // 内容区域
      Scroll() {
        Column({ space: 16 }) {
          // 今日状态卡片
          this.BuildStatusCard()

          // 护眼滤镜卡片
          this.BuildFilterCard()

          // 休息节奏卡片
          this.BuildRestCard()

          // 系统设置卡片
          this.BuildSettingsCard()
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .margin({ top: 64 })
    }
    .width('100%')
    .height('100%')
  }

  // 状态卡片
  @Builder
  BuildStatusCard() {
    Column() {
      Text('今日护眼状态').fontSize(14).fontColor('#86909C').alignSelf(ItemAlign.Start)
      Text('保持专注，但别忘了休息一下眼睛。')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')
        .margin({ top: 8 })
        .alignSelf(ItemAlign.Start)
      Row({ space: 32 }) {
        Column() {
          Text('今日休息次数').fontSize(14).fontColor('#86909C')
          Text(`${this.restTimes} 次`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#182431').margin({ top: 4 })
        }
        Column() {
          Text('昨日休息次数').fontSize(14).fontColor('#86909C')
          Text(`${this.preRestTimes} 次`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#182431').margin({ top: 4 })
        }
        Column() {
          Text('下一次休息').fontSize(14).fontColor('#86909C')
          Text(this.nextRestCountdown).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#007DFF').margin({ top: 4 })
        }
      }
      .margin({ top: 16 })
      .alignSelf(ItemAlign.Start)
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  // 滤镜卡片
  @Builder
  BuildFilterCard() {
    Column() {
      Row() {
        Column() {
          Text('护眼滤镜').fontSize(14).fontColor('#86909C')
          Text('过滤蓝光').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#182431').margin({ top: 4 })
        }
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.filterEnabled })
          .selectedColor('#007DFF')
          .onChange((val) => this.toggleFilter(val))
      }
      .width('100%')

      // 强度滑块
      if (this.filterEnabled) {
        Column() {
          Row() {
            Text('强度').fontSize(16).fontColor('#182431')
            Blank()
            Text(`${this.filterStrength}%`).fontSize(16).fontColor('#007DFF')
          }
          .width('100%')
          Slider({ value: this.filterStrength, min: 0, max: 100, step: 1 })
            .width('100%')
            .blockColor('#007DFF')
            .trackColor('#E5E6EB')
            .selectedColor('#007DFF')
            .onChange((val) => {
              this.filterStrength = val;
              if (this.activePreset === '自设' && this.prefs) {
                this.prefs.put('filterStrength', val);
                this.prefs.flush();
              }
            })
        }
        .margin({ top: 20 })

        // 预设按钮
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(Object.keys(PRESETS), (preset: string) => {
            Button(preset)
              .fontSize(14)
              .height(36)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.activePreset === preset ? '#007DFF' : '#F2F3F5')
              .fontColor(this.activePreset === preset ? '#FFFFFF' : '#182431')
              .borderRadius(18)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.switchPreset(preset))
          })
        }
        .width('100%')
        .margin({ top: 16 })

        // 色温滑块
        Column() {
          Row() {
            Text('色调').fontSize(16).fontColor('#182431')
            Blank()
            Text(`${this.colorTemp}K`).fontSize(16).fontColor('#007DFF')
          }
          .width('100%')
          Slider({ value: this.colorTemp, min: 3000, max: 10000, step: 100 })
            .width('100%')
            .blockColor('#007DFF')
            .trackColor('#E5E6EB')
            .selectedColor('#007DFF')
            .onChange((val) => {
              this.colorTemp = val;
              if (this.activePreset === '自设' && this.prefs) {
                this.prefs.put('colorTemp', val);
                this.prefs.flush();
              }
            })
        }
        .margin({ top: 20 })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  // 休息卡片
  @Builder
  BuildRestCard() {
    Column() {
      Row() {
        Column() {
          Text('定时休息').fontSize(14).fontColor('#86909C')
          Text('休息节奏').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#182431').margin({ top: 4 })
        }
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.restEnabled })
          .selectedColor('#007DFF')
          .onChange((val) => this.toggleRest(val))
      }
      .width('100%')

      if (this.restEnabled) {
        // 休息间隔/时长
        Row({ space: 16 }) {
          Row() {
            Text('每隔').fontSize(16).fontColor('#182431')
            TextInput({ text: this.restMinutes.toString() })
              .type(InputType.Number)
              .width(60)
              .textAlign(TextAlign.Center)
              .onChange((val) => {
                const num = Math.min(180, Math.max(30, parseInt(val) || 30));
                this.restMinutes = num;
                if (this.prefs) {
                  this.prefs.put('restMinutes', num);
                  this.prefs.flush();
                }
                this.nextRestAt = this.getNextRestTime();
              })
            Text('分钟').fontSize(16).fontColor('#182431')
          }
          .padding(12)
          .backgroundColor('#F2F3F5')
          .borderRadius(8)

          Row() {
            Text('休息').fontSize(16).fontColor('#182431')
            TextInput({ text: this.restDuration.toString() })
              .type(InputType.Number)
              .width(60)
              .textAlign(TextAlign.Center)
              .onChange((val) => {
                const num = Math.min(30, Math.max(1, parseInt(val) || 1));
                this.restDuration = num;
                if (this.prefs) {
                  this.prefs.put('restDuration', num);
                  this.prefs.flush();
                }
              })
            Text('分钟').fontSize(16).fontColor('#182431')
          }
          .padding(12)
          .backgroundColor('#F2F3F5')
          .borderRadius(8)
        }
        .margin({ top: 20 })

        // 倒计时
        Column() {
          Text('距离下次休息还有').fontSize(14).fontColor('#86909C')
          Text(this.nextRestCountdown)
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor('#007DFF')
            .margin({ top: 8 })
        }
        .margin({ top: 20 })

        // 立即休息按钮
        Button('立即进入休息')
          .width('100%')
          .height(48)
          .backgroundColor('#E8F3FF')
          .fontColor('#007DFF')
          .fontSize(16)
          .margin({ top: 20 })
          .onClick(() => this.startRest())
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  // 设置卡片
  @Builder
  BuildSettingsCard() {
    Column() {
      Text('系统设置').fontSize(14).fontColor('#86909C').alignSelf(ItemAlign.Start)

      Column({ space: 20 }) {
        // 开启护眼
        Row() {
          Text('开启护眼').fontSize(16).fontColor('#182431')
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.filterEnabled })
            .selectedColor('#007DFF')
            .onChange((val) => this.toggleFilter(val))
        }
        .width('100%')

        // 快捷键
        Row() {
          Text('定时休息快捷键（Alt + Shift + 1）').fontSize(16).fontColor('#182431')
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.autoKeyEnabled })
            .selectedColor('#007DFF')
            .onChange(async (val) => {
              this.autoKeyEnabled = val;
              if (this.prefs) {
                await this.prefs.put('autoKeyEnabled', val);
                await this.prefs.flush();
              }
              // ⚠️ 组合键监听需使用 @ohos.multimodalInput.inputEventClient，需声明权限
            })
        }
        .width('100%')

        // 开机自启
        Row() {
          Text('开机自启').fontSize(16).fontColor('#182431')
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.startupEnabled })
            .selectedColor('#007DFF')
            .onChange((val) => this.toggleStartup(val))
        }
        .width('100%')
      }
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}