# Vanilla Acid — iPhone / iPad アプリ（自分用・無料）

Web 版をそのまま WKWebView に入れ、CoreMIDI（USB / Bluetooth / ネットワークMIDI）を Web MIDI として使えるようにしたラッパーです。

## 初回
1. Mac に Xcode を入れる（App Store、無料）。Homebrew が無ければ https://brew.sh
2. このリポジトリを clone して `ios/setup.sh` を実行（xcodegen を自動インストール → Xcode が開く）
3. Xcode: 左の VanillaAcid → Signing & Capabilities → Team に自分の Apple ID を選ぶ（無料でOK。出ない時は Xcode > Settings > Accounts で追加）
4. iPhone を USB で接続 →「信頼」→ 設定 > プライバシーとセキュリティ > デベロッパモード をオン（再起動）
5. Xcode 上部で自分の iPhone を選んで ▶︎ ビルド
6. 初回起動前に iPhone で 設定 > 一般 > VPNとデバイス管理 > 自分のApple ID を「信頼」

## 更新するとき
`git pull` → `ios/setup.sh` → ▶︎

## 注意
- 無料のApple IDだと **7日で期限切れ**。切れたらXcodeからもう一度 ▶︎ するだけ（データは残ります）
- MIDI は iPhone に USB-C（またはLightning）で機器を接続。Bluetooth MIDI は iOS の設定側で先にペアリング
- 実機未検証のコードです。ビルドエラーや挙動の不具合は内容を教えてください
