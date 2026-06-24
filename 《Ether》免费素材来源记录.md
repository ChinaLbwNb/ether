# 《Ether》免费素材来源记录

## 使用原则

1. 优先使用 CC0 / Public Domain / 明确可商用授权的素材。
2. 下载前再次确认素材页的许可证。
3. 保留素材来源 URL、作者、许可证和下载日期。
4. 不使用《The Riftbreaker》原始素材、截图、图标、音效或商标内容。
5. 免费素材只作为原型和早期正式资源来源，关键角色与核心建筑后期建议原创化统一风格。

## 第一批推荐来源

| 来源 | 许可证 | 适合内容 | 备注 |
| --- | --- | --- | --- |
| https://kenney.nl/assets/sci-fi-rts | Creative Commons CC0 | 科幻 RTS 建筑、基地、地块 | 优先用于基地、生产建筑、科幻建筑占位 |
| https://kenney.nl/assets/tower-defense-top-down | Creative Commons CC0 | 塔防炮塔、敌人、地形、HUD 数字 | 优先用于哨兵塔、塔防原型、敌人占位 |
| https://opengameart.org/content/tower-defense-300-tilessprites | CC0 | 塔防完整包，含塔、敌人、粒子、地块 | Kenney 发布在 OpenGameArt 的同类素材包 |
| https://itch.io/game-assets/assets-cc0/tag-science-fiction | Creative Commons Zero 筛选页 | 科幻 CC0 素材集合 | 逐个素材页核对许可证后再用 |
| https://opengameart.org/content/sci-fi-turret | CC0 | 科幻炮塔 3D 原型 | 后期可渲染成 2D 塔图或参考造型 |

## v0.1 资产替换建议

| 游戏内资产 | 临时方案 | 免费素材替换方向 |
| --- | --- | --- |
| 基地核心 | 脚本绘制圆形核心 | Kenney Sci-Fi RTS 建筑 |
| 哨兵塔 | 脚本绘制底座 + 炮管 | Kenney Tower Defense Top-Down 炮塔 |
| 小型敌人 | 脚本绘制红色圆形 | Kenney Tower Defense 敌人或 CC0 科幻怪物 |
| 能量矿 | 脚本绘制发光矿石 | OpenGameArt / itch.io CC0 晶体或矿物 |
| 子弹 | 脚本绘制发光圆点 | Kenney 粒子或自行绘制 |
| HUD 图标 | 文本占位 | Kenney UI / OpenGameArt CC0 图标 |

## 已下载并接入项目的素材

下载日期：2026-06-24

| 游戏内资产 | 项目引用文件 | 原始素材文件 | 来源 | 许可证 |
| --- | --- | --- | --- | --- |
| 基地核心 | `res://art/gameplay/base/base_core.png` | `kenney_sci-fi-rts/PNG/Default size/Structure/scifiStructure_01.png` | https://kenney.nl/assets/sci-fi-rts | Creative Commons CC0 |
| 能量矿 | `res://art/gameplay/resources/energy_crystal.png` | `kenney_sci-fi-rts/PNG/Default size/Environment/scifiEnvironment_10.png` | https://kenney.nl/assets/sci-fi-rts | Creative Commons CC0 |
| 哨兵塔 | `res://art/gameplay/towers/sentry_tower.png` | `kenney_tower-defense-top-down/PNG/Default size/towerDefense_tile203.png` | https://kenney.nl/assets/tower-defense-top-down | Creative Commons CC0 |
| 小型敌人 | `res://art/gameplay/enemies/enemy_scout.png` | `kenney_tower-defense-top-down/PNG/Default size/towerDefense_tile245.png` | https://kenney.nl/assets/tower-defense-top-down | Creative Commons CC0 |
| 铁矿 | `res://art/gameplay/resources/iron_ore.png` | `kenney_sci-fi-rts/PNG/Default size/Environment/scifiEnvironment_08.png` | https://kenney.nl/assets/sci-fi-rts | Creative Commons CC0 |
| 碳矿 | `res://art/gameplay/resources/carbon_ore.png` | `kenney_sci-fi-rts/PNG/Default size/Environment/scifiEnvironment_01.png` | https://kenney.nl/assets/sci-fi-rts | Creative Commons CC0 |
| 采矿机 | `res://art/gameplay/production/mining_drill.png` | `kenney_sci-fi-rts/PNG/Default size/Structure/scifiStructure_09.png` | https://kenney.nl/assets/sci-fi-rts | Creative Commons CC0 |
| 发电机 | `res://art/gameplay/production/power_generator.png` | `kenney_sci-fi-rts/PNG/Default size/Structure/scifiStructure_08.png` | https://kenney.nl/assets/sci-fi-rts | Creative Commons CC0 |

本地保留的原始压缩包：

- `res://art/external/kenney/downloads/kenney_sci-fi-rts.zip`
- `res://art/external/kenney/downloads/kenney_tower-defense-top-down.zip`

## 后续需要继续搜索的素材

- 顶视角机甲角色，最好带待机、移动、受击、攻击动画。
- 科幻建筑损坏状态。
- 异星资源矿脉。
- 虫群/异星生物敌人。
- 科幻武器音效。
- 塔防命中特效、爆炸、护盾、光束。

## 授权风险记录

- itch.io 免费素材不等于可商用，必须进入单个素材页确认许可证。
- OpenGameArt 素材可能有 CC-BY / GPL / OGA-BY 等不同许可证，只有 CC0 最适合直接使用。
- CC-BY 可以用，但必须做署名系统和 credits 文件；当前阶段优先不用。
- AI 生成素材需要确认平台授权和训练/再分发限制；当前阶段不作为首选。
