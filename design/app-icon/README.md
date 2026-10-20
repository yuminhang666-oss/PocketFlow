# PocketFlow 0.3.1 应用图标

`source.png` 为用户 2026-10-20 提供并指定用于本应用的蓝白钱包原图，原样保存。未重新生成或重绘图案；不据此宣称拥有第三方素材的版权。

运行 `pwsh -File tools/generate-launcher-icons.ps1` 生成 Android 24–25 的五档传统图标及 Android 26+ 的自适应图标底图。只进行确定性的尺寸转换和安全区装配，不新增依赖。

自适应图标使用 108dp 图层，原图缩放为中心 84dp，主体位于中央安全区。背景与透明前景保持原图整体，避免桌面动效拆散钱包；由系统负责圆形、圆角矩形等最终裁切。`roundIcon` 指向同一资源。原图仅作设计源文件，不作为 Flutter 运行时资产打包。

参考：[Android adaptive icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)。真实设备验证及限制见 `docs/v0.3.1-icon-update.md`。
