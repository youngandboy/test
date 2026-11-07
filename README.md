# 人情簿

鸿蒙（HarmonyOS）人情往来管理应用。用来记录收礼、送礼，管理联系人和回礼提醒，所有数据仅保存在本机。

## 功能

- **首页看板**：人情余额、累计收礼/送礼、待回礼提醒、最近往来。
- **人情账**：按收礼/送礼筛选、关键词搜索，新增、编辑、长按删除记录。
- **通讯录**：按关系管理联系人，查看单人收送汇总和全部往来记录。
- **统计**：收送对比、近六个月趋势、联系人差额排行，支持一键清空本地数据。
- **示例数据**：首次启动且数据为空时，可一键载入演示数据体验完整流程。

## 模块化设计

项目按“公共层 / UI 组件库 / 数据层 / 功能模块 / 应用壳”拆分，依赖方向始终由外向内：

```
entry (HAP)
  ├── feature_home          ┐
  ├── feature_records       │ 功能模块（HAR）
  ├── feature_contacts      │
  └── feature_statistics    ┘
        │            │
        ▼            ▼
     data (HAR)    ui (HAR)
        │            │
        ▼            ▼
          commons (HAR)
```

| 模块 | 类型 | 职责 | 依赖 |
| --- | --- | --- | --- |
| `entry` | HAP | 应用入口、底部导航、Tab 切换、跨 Tab 指令 | 四个 feature + data + commons |
| `commons` | HAR | 领域模型、枚举、统计规则、日期/金额工具、主题 | 无 |
| `ui` | HAR | 基础 UI 组件（EmptyState、Avatar、Tag、StatTile、SectionTitle） | commons |
| `data` | HAR | Preferences 持久化、单例仓库、示例数据 | commons |
| `features/home` | HAR | 首页看板 | commons、ui、data |
| `features/records` | HAR | 人情账列表与记录编辑 | commons、ui、data |
| `features/contacts` | HAR | 通讯录、联系人详情与编辑 | commons、ui、data |
| `features/statistics` | HAR | 统计图表与数据清理 | commons、ui、data |

分层约束：

- 页面不直接读写存储，只调用 `FavorRepository`。
- 统计口径全部在 `FavorAnalytics` 纯函数中实现，首页、通讯录、统计页共用一套规则。
- 颜色、圆角在 `commons` 统一定义，基础组件在 `ui` 统一维护，四个功能模块保持一致的视觉语言。
- 功能模块之间不互相依赖，跨 Tab 交互通过 `entry` 传入的回调完成。

## 目录结构

```
.
├── AppScope/                       应用级配置与图标
├── entry/                          应用入口 HAP
│   ├── src/main/ets/entryability/  初始化数据仓库
│   └── src/main/ets/pages/Index.ets 底部导航壳
├── commons/                        公共领域层 HAR
│   └── src/main/ets/
│       ├── domain/                 模型、枚举、FavorAnalytics
│       ├── utils/                  日期、金额、ID
│       └── theme/                  AppTheme 视觉基线
├── ui/                             基础组件 HAR
│   └── src/main/ets/components/    EmptyState、Avatar、Tag、StatTile、SectionTitle
├── data/                           数据层 HAR
│   └── src/main/ets/
│       ├── storage/                FavorPreferences
│       ├── repository/             FavorRepository
│       └── sample/                 SampleData
├── features/
│   ├── home/                       首页看板
│   ├── records/                    人情账 + 记录编辑弹窗
│   ├── contacts/                   通讯录 + 联系人编辑弹窗
│   └── statistics/                 统计分析
└── build-profile.json5             多模块构建配置
```

## 数据模型

- `Person`：联系人（姓名、关系、手机号、备注）。
- `FavorRecord`：一笔人情（联系人、收礼/送礼、金额、场合、日期、备注）。
- `PersonBalance`：按联系人聚合的收送汇总，`net = 收礼 - 送礼`。
- `FavorStatistics` / `MonthlyBalance`：全局统计与月度统计。

差额语义：

- `net > 0`：收到的更多，显示“待回礼”。
- `net < 0`：送出的更多，显示“对方欠我”。
- `net = 0`：显示“已两清”。

本地存储使用 `@kit.ArkData` 的 Preferences，联系人和记录分别以 JSON 字符串保存。仓库层负责模型解析、写入和示例数据，页面不感知存储细节。

## 构建运行

1. 使用 DevEco Studio 打开项目根目录，等待 `ohpm install` 完成。
2. 选择 `entry` 模块，使用 API 24 及以上的 HarmonyOS SDK。
3. 连接真机或启动模拟器后运行。

命令行构建（需要本机已配置 HarmonyOS SDK 与 hvigor）：

```bash
ohpm install
hvigorw --mode module -p module=entry@default -p product=default assembleHap
```

## 测试

`entry/src/test/LocalUnit.test.ets` 覆盖领域层核心规则：

- 收礼/送礼/净额统计；
- 按联系人聚合与差额排序；
- 待回礼筛选；
- 记录按日期倒序；
- 金额千分位格式化；
- 日期格式校验。

在 DevEco Studio 中通过 `entry` 的 Local Test 运行。
