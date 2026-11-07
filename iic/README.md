# 嵌入式 IIC（I2C）主机驱动

一份可直接用于单片机、也可在电脑上模拟验证的完整 I2C 主机驱动。驱动只依赖 5 个
GPIO/延时回调，不依赖任何芯片厂商库，不动态分配内存，没有全局状态。

## 特性

- 7 位地址，写、读、写-读（重复起始）三种传输
- 标准模式 100 kHz、快速模式 400 kHz 或任意可实现的速率
- 支持从机时钟拉伸（clock stretching），带超时保护
- `iic_init()` 自动检查总线空闲；SDA 被从机拉住时自动发 9 个 SCL 时钟恢复
- 地址 NACK、数据 NACK、总线卡死、时钟拉伸超时分别返回不同错误码
- 支持总线扫描 `iic_scan()`
- 轮询/阻塞式实现，代码量小，易审计

## 文件结构

```
iic/
├── include/
│   ├── iic.h        # 公共 API、端口回调、错误码
│   └── iic_sim.h    # 仿真总线与虚拟从机 API（仅主机测试使用）
├── src/
│   └── iic.c        # 驱动实现（移植时只需要这个文件和 iic.h）
├── sim/
│   └── iic_sim.c    # 位级 I2C 总线仿真器
├── test/
│   └── test_iic.c   # 模拟测试用例
├── examples/
│   └── demo_iic.c   # EEPROM + 传感器演示
└── Makefile
```

## 快速开始

需要 C99 编译器和 make：

```sh
cd iic
make test     # 编译并运行全部模拟测试
make demo     # 运行 EEPROM/传感器示例
```

`make test` 成功时输出：

```
all tests passed
```

## 硬件移植

把 SCL、SDA 配置为开漏输出并启用上拉（模块外部一般已有 4.7 kΩ 上拉电阻），然后
实现 `iic_port_t` 的 5 个回调：

| 回调 | 要求 |
| --- | --- |
| `scl_write(ctx, level)` | `level=1` 释放 SCL（开漏高阻），`level=0` 拉低 |
| `scl_read(ctx)` | SCL 为高返回 1，为低返回 0 |
| `sda_write(ctx, level)` | 同 SCL，开漏输出 |
| `sda_read(ctx)` | SDA 为高返回 1，为低返回 0 |
| `delay_half_bit(ctx)` | 延时半个 SCL 周期：100 kHz 约 5 µs，400 kHz 约 1.25 µs |

以 STM32 HAL（PB6 = SCL，PB7 = SDA，100 kHz）为例：

```c
/* GPIO 初始化：开漏 + 上拉 */
GPIO_InitTypeDef gpio = {0};
gpio.Pin   = GPIO_PIN_6 | GPIO_PIN_7;
gpio.Mode  = GPIO_MODE_OUTPUT_OD;
gpio.Pull  = GPIO_PULLUP;
gpio.Speed = GPIO_SPEED_FREQ_HIGH;
HAL_GPIO_Init(GPIOB, &gpio);

static void scl_write(void *ctx, int level)
{
    (void)ctx;
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_6, level ? GPIO_PIN_SET : GPIO_PIN_RESET);
}
static int scl_read(void *ctx)
{
    (void)ctx;
    return HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_6) == GPIO_PIN_SET;
}
static void sda_write(void *ctx, int level)
{
    (void)ctx;
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_7, level ? GPIO_PIN_SET : GPIO_PIN_RESET);
}
static int sda_read(void *ctx)
{
    (void)ctx;
    return HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_7) == GPIO_PIN_SET;
}
static void delay_half_bit(void *ctx)
{
    (void)ctx;
    delay_us(5); /* 100 kHz；400 kHz 改为 1.25 µs 的高精度延时 */
}

iic_bus_t bus;
iic_config_t config = {0};

config.port.ctx           = NULL;
config.port.scl_write     = scl_write;
config.port.scl_read      = scl_read;
config.port.sda_write     = sda_write;
config.port.sda_read      = sda_read;
config.port.delay_half_bit = delay_half_bit;
/* 可选：config.scl_timeout_loops 默认 1000 个半位延时；
   config.recover_clocks 默认 9。 */

if (iic_init(&bus, &config) != IIC_OK) {
    /* 总线被拉死，检查接线、上拉和从机供电 */
}
```

注意：

- `iic_init()` 会释放两条线并检查空闲；若 SDA/SCL 为低，会发最多 9 个时钟再发
  STOP。恢复失败返回 `IIC_ERR_BUS`。
- 驱动是阻塞式的，且不是线程安全的。多任务/中断同时访问同一总线时，应用层需要
  加锁，并在一次完整传输期间避免同引脚被中断操作。
- 上拉电阻、总线电容和从机速度决定实际可用速率；先用 100 kHz 调通。

## API 与用法

### EEPROM 写入与读回

```c
uint8_t page[5] = {0x00, 0xAA, 0xBB, 0xCC, 0xDD}; /* 首字节为 EEPROM 地址 */
uint8_t reg = 0x00;
uint8_t data[4];

iic_write(&bus, 0x50, page, sizeof(page));          /* 写 4 字节到 0x00 */
iic_write_read(&bus, 0x50, &reg, 1, data, 4);      /* 0x00 开始读 4 字节 */
```

### 传感器寄存器读取

```c
uint8_t reg = 0x01;
uint8_t value[2];

if (iic_write_read(&bus, 0x48, &reg, 1, value, 2) == IIC_OK) {
    /* value[0] / value[1] */
}
```

### 扫描总线

```c
uint8_t addrs[16];
size_t found;

if (iic_scan(&bus, addrs, 16, &found) == IIC_OK) {
    /* found 为设备总数；addrs 中最多 16 个地址 */
}
```

### 错误处理

所有传输返回 `iic_status_t`：

| 返回值 | 含义 |
| --- | --- |
| `IIC_OK` | 传输完成，所有字节均被 ACK |
| `IIC_ERR_PARAM` | 参数错误或驱动未初始化 |
| `IIC_ERR_NACK_ADDR` | 地址字节无从机应答 |
| `IIC_ERR_NACK_DATA` | 数据字节被从机 NACK |
| `IIC_ERR_TIMEOUT` | SCL 被拉低超过 `scl_timeout_loops` 个半位延时 |
| `IIC_ERR_BUS` | 总线被拉死或无法恢复 |

出现 `IIC_ERR_TIMEOUT` / `IIC_ERR_BUS` 后可调用 `iic_recover()` 清总线；传输过程
中的 NACK 会自动发 STOP，总线仍可继续使用。

## 仿真测试

`sim/iic_sim.c` 不是“假 API”：它按位模拟开漏总线、START/STOP、ACK/NACK 和时钟
拉伸，驱动跑的是与真实硬件完全相同的位操作代码。仿真从机包括：

- 24Cxx 风格 EEPROM（256 字节，内部地址指针）
- 只读传感器
- 每次地址 ACK 都拉伸 SCL 的从机
- ACK 地址、NACK 首个数据字节的从机
- 可用 `iic_sim_hold_sda()` 注入 SDA 卡死故障

测试覆盖：

1. 参数校验、重复初始化、未初始化时调用
2. 地址探测、总线扫描（含输出缓冲区不足）
3. EEPROM 写、随机读、当前地址连续读、指针保持
4. 写-读组合传输与 `tx_len == 0`
5. 地址 NACK / 数据 NACK 后总线仍可用
6. 传感器读
7. 时钟拉伸等待与超时
8. `iic_init()` 自动恢复、永久卡死失败、显式 `iic_recover()`、恢复后继续通信
9. 仿真器观测到的 START/STOP 数量与传输方式一致

## 限制

- 仅实现 I2C 主机，单主机；不支持多主机仲裁和 10 位地址
- 阻塞式轮询，不支持 DMA/中断传输；不适合超长传输或低功耗严格场景
- 不包含 SMBus PEC、ARP、超时复位等 SMBus 扩展
- 仿真器验证的是协议时序和驱动状态机，不模拟真实总线的上升沿、噪声和电平容限；
  上板前仍需用示波器/逻辑分析仪确认波形和上拉
