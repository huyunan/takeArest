import { window } from '@kit.ArkUI';
import { formatDuration2 } from '../common/utils';

@Entry
@Component
struct LockScreen {
  @State now: Date = new Date();
  @State endAtMs: number = 0;
  private timerId: number = -1;

  get timeText(): string {
    return this.now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  }

  get dateText(): string {
    return this.now.toLocaleDateString('zh-CN', { month: 'long', day: 'numeric', weekday: 'short' });
  }

  get countdown(): string {
    const diff = (this.endAtMs - this.now.getTime()) / 1000;
    return formatDuration2(diff);
  }

  aboutToAppear() {
    // const params = getContext(this).getStartupParams() as Record<string, number>;
    // this.endAtMs = params['endAtMs'] || 0;
    this.endAtMs = 5000;
    this.timerId = setInterval(() => {
      this.now = new Date();
      if (this.now.getTime() >= this.endAtMs) this.exitRest();
    }, 500);
  }

  onDisappear() {
    if (this.timerId !== -1) clearInterval(this.timerId);
  }

  private async exitRest() {
    try {
      const win = window.findWindow('lock_window');
      if (win) await win.destroyWindow();
    } catch (e) {}
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 半透明背景
      Column() {}.width('100%').height('100%').backgroundColor('#000000').opacity(0.85)

      // 内容
      Column() {
        // 顶部时间
        Row() {
          Column() {
            Text(this.timeText).fontSize(56).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
            Text(this.dateText).fontSize(18).fontColor('#AAAAAA').margin({ top: 8 })
          }
          Blank()
        }
        .width('100%')
        .padding({ left: 32, right: 32, top: 48 })

        Blank()

        // 中间倒计时
        Column() {
          Text('休息一下，放松眼睛').fontSize(28).fontColor('#FFFFFF')
          Text(this.countdown.replaceAll(':', ' : '))
            .fontSize(72)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .margin({ top: 24 })
          Button('跳过休息')
            .height(48)
            .padding({ left: 32, right: 32 })
            .backgroundColor('#333333')
            .fontColor('#FFFFFF')
            .margin({ top: 40 })
            .onClick(() => this.exitRest())
        }

        Blank()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}