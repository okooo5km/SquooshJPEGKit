# 面向 Squoosh 对齐的 JPEG 核心库实现规划

> 目标不是做一个“泛用 MozJPEG Swift 封装”，而是做一个 **严格以 Squoosh 为参考真值** 的 JPEG 核心库：
>
> - **编码器行为**尽可能对齐 Squoosh 的 MozJPEG 路径；
> - **像素预处理**（rotate / resize）尽可能对齐 Squoosh 的处理语义；
> - **Metadata** 默认遵循 Squoosh 的“编码链本身不保留 marker”原则，但同时提供 Zipic 所需的可扩展 metadata policy；
> - 为 Zipic 提供一套可验证、可测试、可长期维护的 native core。

---

## 1. 结论先行

如果最终目标是：

> **尽可能和 Squoosh 里的 JPEG 压缩结果一致**

那么最值得做的不是继续堆 CLI 参数，而是先做一个：

- **Squoosh-aligned native core**
- 以 **MozJPEG 3.3.1 + Squoosh 同构参数模型 + 同构像素输入模型** 为核心
- 并把 **resize / rotate / metadata policy** 一并纳入统一管线

### 我的明确判断

1. **这条路可行。**
2. **而且能做得很好。**
3. 真正要避免的是：
   - 做成“普通 MozJPEG Swift wrapper”；
   - 只包一层 `jpeglib.h`，却没有把 Squoosh 的隐藏默认值、输入模型、resize 行为一并锁死。

### 这份规划的核心原则

> 先保证“**Squoosh-compatible**”，再考虑“Zipic-friendly”。

也就是说：

- **第一优先级**：对齐 Squoosh 的真实实现；
- **第二优先级**：在不破坏对齐的前提下，为 Zipic 增加 metadata preserve、文件输入、业务 preset 等增强能力。

---

## 2. 参考真值（Ground Truth）

这部分是后续所有设计必须锁定的“基线事实”。

## 2.1 Squoosh 的 JPEG 编码核心事实

已经确认的 Squoosh JPEG 编码事实如下：

- 编码器：**MozJPEG 3.3.1**
- 运行形态：**Wasm / Worker 内存调用**
- 不是 CLI，不走 `cjpeg` 子进程
- 输入：**RGBA `ImageData`**
- 输出：**内存中的 JPEG 字节数组**
- 关键默认值：
  - `quality = 75`
  - `baseline = false`
  - `progressive = true`
  - `optimize_coding = true`
  - `smoothing = 0`
  - `color_space = YCbCr`
  - `quant_table = 3`
  - `auto_subsample = true`
  - `chroma_subsample = 2`
  - `separate_chroma_quality = false`
  - `chroma_quality = 75`
  - `trellis_multipass = false`
  - `trellis_opt_zero = false`
  - `trellis_opt_table = false`
  - `trellis_loops = 1`

## 2.2 Squoosh 仍然继承的 MozJPEG 隐藏默认值

这是实现时最容易漏掉，但又最关键的部分：

- `compress_profile = JCP_MAX_COMPRESSION`
- `trellis_quant = true`
- `trellis_quant_dc = true`
- `optimize_scans = true`
- `overshoot_deringing = true`
- `use_lambda_weight_tbl = true`
- `lambda_log_scale1 = 14.75`
- `lambda_log_scale2 = 16.5`

## 2.3 一个必须显式对齐的关键差异

Squoosh 在 `mozjpeg_enc.cpp` 里显式设置：

- `JINT_DC_SCAN_OPT_MODE = 0`

而 MozJPEG 默认行为更接近：

- `dc_scan_opt_mode = 1`

这个点如果漏掉，会导致：

- progressive scan 行为差异
- 文件结构差异
- 和 Squoosh 输出偏离

## 2.4 Squoosh 的构建特征（也应作为 native 对齐参考）

Squoosh 的 MozJPEG 构建特征：

- MozJPEG 版本：**3.3.1**
- Emscripten 参考环境：**2.0.34**（仅作来源参考，不是 native 最终构建工具）
- configure flags：
  - `--disable-shared`
  - `--without-turbojpeg`
  - `--without-simd`
  - `--without-arith-enc`
  - `--without-arith-dec`

### 这意味着 native wrapper 也应先对齐这些特性

如果目标是 Squoosh 对齐，而不是“更快更新版本”，第一阶段建议：

- **仍使用 MozJPEG 3.3.1**
- **先禁用 SIMD**
- **先禁用 arithmetic coding**
- **不要偷偷升级到 4.x**

否则你做出来的将是“新的 MozJPEG native encoder”，而不是“Squoosh-compatible encoder”。

---

## 3. 这套库到底要解决什么，不解决什么

## 3.1 要解决的问题

这套库应解决 4 类问题：

1. **编码器级对齐**
   - 让 Swift/native 环境里能按 Squoosh 的 MozJPEG 方式编码 JPEG。

2. **像素准备链对齐**
   - 让 rotate / resize / premultiply / linearRGB / fitMethod 的语义尽量与 Squoosh 一致。

3. **Metadata 策略统一**
   - 默认遵循 Squoosh：不保留 metadata；
   - 但同时为 Zipic 提供可控的 metadata policy，替代 `jpegoptim --strip-all` 这种外部补丁式方案。

4. **可验证性**
   - 提供 diagnostics、golden tests、对照工具，能证明“哪里对齐了，哪里属于边界差异”。

## 3.2 不解决的问题

第一阶段不应该试图解决这些：

1. **做最新 MozJPEG 4.x 路线**
   - 那是第二条路线，不应和 Squoosh 对齐路线混在一起。

2. **复刻浏览器解码器本身**
   - Squoosh 里 JPEG/PNG/WebP/AVIF 的解码很多时候依赖浏览器或 worker decoder。
   - native 库无法真正“复刻浏览器像素输出”。
   - 所以应把严格对齐边界定义为：
     - **从 RGBA 输入开始对齐**。

3. **第一阶段覆盖所有 Squoosh 解码格式**
   - QOI/JXL/WP2/AVIF 的完整解码兼容，不应阻塞 JPEG 核心库落地。

4. **第一阶段做成全平台通用图像 SDK**
   - 先聚焦 macOS / Swift / Zipic 的真实需求。

---

## 4. 成功标准（Success Criteria）

## 4.1 编码器级成功标准

对同一组 **RGBA fixture + 同一组 Squoosh 参数**：

- 输出 JPEG 尽可能达到：
  - **字节级一致**，或者
  - 至少达到以下结构级一致：
    - quant tables 一致
    - sampling factors 一致
    - progressive scan script 一致
    - marker 结构一致（在 metadata policy 相同前提下）
    - 文件大小高度接近

## 4.2 resize 级成功标准

对同一组 RGBA fixture + 同一组 resize 参数：

- 输出 RGBA 与 Squoosh resize wasm 结果：
  - 尽量字节一致；
  - 至少视觉无差异，边缘和 gamma 行为一致；
  - 尤其要对齐：
    - `premultiply`
    - `linearRGB`
    - `contain` 裁切计算与 rounding

## 4.3 metadata 级成功标准

- `squooshDropAll` 模式下：
  - 输出不带源文件 EXIF/ICC/XMP/COM 等 marker；
  - 不再依赖 `jpegoptim --strip-all`。
- preserve 模式下：
  - marker copy/write 结果可预测；
  - 行为由 policy 明确定义，而不是被外部 CLI 副作用决定。

---

## 5. 库的范围与边界

## 5.1 建议产品定位

建议库名先按能力定位，而不是按“通用 MozJPEG”定位：

- `SquooshJPEGKit`
- 或 `SquooshAlignedJPEG`

不建议第一阶段叫得太泛，比如：

- `MozJPEGSwift`
- `SwiftMozJPEG`

因为这会让团队不自觉地把目标从“对齐 Squoosh”扩散成“包所有 MozJPEG 能力”。

## 5.2 推荐的公开边界

这套库应提供两层 API：

### A. 严格核心层（必须有）

只接受：

- `RGBA8` buffer
- width / height
- squoosh-compatible options

这是**真正的对齐核心**。

### B. 高级管线层（建议有）

接受：

- `CGImage`
- `CGImageSource`
- `Data`
- 文件 URL

并负责：

- orientation policy
- rotate
- resize
- metadata policy
- encode

但必须明确标注：

> 这一层是“Zipic-friendly pipeline”，不是字节级 Squoosh 真值层。  
> 真正的严格对齐基准，仍然是核心层的 RGBA 输入。

---

## 6. 推荐架构

```mermaid
graph TD
    A[Zipic / Other Apps] --> B[SquooshJPEGKit Swift API]
    B --> C[SquooshPipeline]
    B --> D[SquooshEncoder]
    C --> E[Decode Adapter\nCGImageSource / caller RGBA]
    C --> F[Rotate Core\n0/90/180/270]
    C --> G[Resize Core\nSquoosh resize parity]
    C --> H[Metadata Policy\ndrop / preserve / copy]
    D --> I[CMozJPEGSquooshCore]
    I --> J[MozJPEG 3.3.1 vendored]
    G --> K[CSquooshResizeCore]
    K --> L[resize crate 0.5.5\n+ hqx 0.1.0(optional)]
    H --> M[JPEG marker parser/writer]
    C --> D
    D --> N[JPEG Data + Diagnostics]
```

### 架构说明

- `CMozJPEGSquooshCore`
  - 负责最小可验证的 MozJPEG native shim
- `CSquooshResizeCore`
  - 负责复刻 Squoosh resize 行为
- `SquooshJPEGKit`
  - 负责 Swift 类型、错误、diagnostics、pipeline orchestration
- `Metadata Policy`
  - 负责 marker copy / strip / rebuild

---

## 7. 依赖与版本冻结要求

## 7.1 必须冻结的依赖版本

| 组件 | 版本 / 要求 | 说明 |
|---|---|---|
| MozJPEG | **3.3.1** | 必须与 Squoosh 对齐 |
| MozJPEG build flags | `--disable-shared --without-turbojpeg --without-simd --without-arith-enc --without-arith-dec` | 第一阶段建议完全对齐 |
| Squoosh resize core | `squoosh-resize` wrapper **0.1.0** | 参考 Squoosh `codecs/resize` |
| Rust `resize` crate | **0.5.5** | Squoosh 当前 worker resize 依赖 |
| hqx wrapper | `squooshhqx` **0.1.0** | 可作为可选模块 |
| JPEG metadata writer | 自研 / 内部模块 | 不建议继续依赖 jpegoptim 作为最终方案 |

## 7.2 为什么不要直接用 MozJPEG 4.1.2

因为你的目标是：

- **Squoosh 对齐**

而不是：

- “当前 Zipic 内置二进制版本一致”

如果一开始就用 4.1.2：

- 默认值可能不完全相同
- hidden defaults 可能发生变化
- CLI help 一致不代表 library 行为完全一致

所以建议：

### 第一阶段
- 只做 **3.3.1 squoosh-compatible backend**

### 第二阶段（可选）
- 再增加 `backend: .mozjpeg331Squoosh / .mozjpeg412Native`

但不要一开始混在一起。

---

## 8. 公开 API 设计建议

## 8.1 核心类型设计

### 8.1.1 像素输入类型

```swift
public struct RGBAImage {
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let data: Data   // RGBA8, unpremultiplied contract at API boundary
}
```

### 为什么必须有这个类型

因为如果入口直接是：

- `encode(fileURL:)`

那解码器差异、颜色空间差异、metadata 差异都会混进来。  
而我们真正想锁死的“严格 Squoosh 对齐层”，应该从：

- **RGBA 像素**

开始。

---

## 8.2 JPEG 选项类型（必须严格镜像 Squoosh）

```swift
public enum SquooshColorSpace: Int32 {
    case rgb
    case ycbcr
    case grayscale
}

public struct SquooshMozJPEGOptions: Sendable, Hashable {
    public var quality: Int
    public var baseline: Bool
    public var arithmetic: Bool
    public var progressive: Bool
    public var optimizeCoding: Bool
    public var smoothing: Int
    public var colorSpace: SquooshColorSpace
    public var quantTable: Int
    public var trellisMultipass: Bool
    public var trellisOptZero: Bool
    public var trellisOptTable: Bool
    public var trellisLoops: Int
    public var autoSubsample: Bool
    public var chromaSubsample: Int
    public var separateChromaQuality: Bool
    public var chromaQuality: Int
}
```

## 8.2.1 默认值必须直接等于 Squoosh

```swift
extension SquooshMozJPEGOptions {
    public static let squooshDefault = Self(
        quality: 75,
        baseline: false,
        arithmetic: false,
        progressive: true,
        optimizeCoding: true,
        smoothing: 0,
        colorSpace: .ycbcr,
        quantTable: 3,
        trellisMultipass: false,
        trellisOptZero: false,
        trellisOptTable: false,
        trellisLoops: 1,
        autoSubsample: true,
        chromaSubsample: 2,
        separateChromaQuality: false,
        chromaQuality: 75
    )
}
```

### 注意

默认值只是一层。  
实现层还必须同时锁死 hidden defaults：

- `compress_profile = JCP_MAX_COMPRESSION`
- `trellis_quant = true`
- `trellis_quant_dc = true`
- `optimize_scans = true`
- `overshoot_deringing = true`
- `dc_scan_opt_mode = 0`

不能因为 Swift 层 `Options` 一样，就误以为已经“对齐 Squoosh”。

---

## 8.3 resize 选项（必须镜像 Squoosh）

```swift
public enum SquooshResizeMethod: Sendable, Hashable {
    case triangle
    case catrom
    case mitchell
    case lanczos3
    case hqx
}

public enum SquooshFitMethod: Sendable, Hashable {
    case stretch
    case contain
}

public struct SquooshResizeOptions: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var method: SquooshResizeMethod
    public var fitMethod: SquooshFitMethod
    public var premultiply: Bool
    public var linearRGB: Bool
}
```

### 默认值必须等于 Squoosh

- `method = lanczos3`
- `fitMethod = stretch`
- `premultiply = true`
- `linearRGB = true`

### 为什么 resize 不能直接换成 sips / NSImage / CoreImage 近似实现

因为一旦你这么做：

- kernel 不同
- rounding 不同
- premultiply 行为不同
- linear RGB 行为不同

最后即使 MozJPEG 编码器完全对齐，最终输出仍可能和 Squoosh 不一致。

所以如果目标真的是 Squoosh 一致性：

> resize 也必须尽量使用与 Squoosh 同构的算法实现。

---

## 8.4 rotate 选项

Squoosh 的 rotate 是一个非常小但非常明确的预处理器：

- 仅支持 `0 / 90 / 180 / 270`

因此建议：

```swift
public enum SquooshRotation: Int, Sendable, Hashable {
    case rotate0 = 0
    case rotate90 = 90
    case rotate180 = 180
    case rotate270 = 270
}
```

### 不建议第一阶段支持任意角度

因为：

- Squoosh 本身没有任意角度旋转路径；
- 任意角度会引入插值，扩大对齐边界。

---

## 8.5 metadata policy 设计

这部分要同时满足：

- **Squoosh 默认行为**
- **Zipic 业务需求**

建议设计为：

```swift
public enum JPEGMetadataPolicy: Sendable, Hashable {
    case squooshDropAll
    case dropAll
    case preserveICCOnly
    case preserveSafe   // ICC + orientation-normalized safe EXIF subset
    case preserveAllRecognized
}
```

### 语义说明

#### `squooshDropAll`
- 严格对齐 Squoosh 默认行为
- 不复制源 marker
- 不写回 EXIF/ICC/XMP/COM
- 这是 **strict mode** 的默认值

#### `dropAll`
- 结果与 `squooshDropAll` 一样
- 但语义更偏工程用途
- 方便 Zipic 在 UI 上表达“移除全部 metadata”

#### `preserveICCOnly`
- 仅保留 ICC profile
- 适合保色但不保隐私信息

#### `preserveSafe`
- ICC + 安全 EXIF 子集
- 例如去掉 GPS、MakerNote 等高风险字段

#### `preserveAllRecognized`
- 尽量保留识别到的 JPEG marker
- 适合 Zipic 的“完整保留”模式

### 关键设计原则

- **默认值必须是 `squooshDropAll`**
- preserve 是 Zipic 扩展能力，不是 Squoosh 对齐默认值

---

## 8.6 高级管线 API

```swift
public struct SquooshPipelineOptions: Sendable, Hashable {
    public var rotate: SquooshRotation
    public var resize: SquooshResizeOptions?
    public var jpeg: SquooshMozJPEGOptions
    public var metadataPolicy: JPEGMetadataPolicy
    public var decodePolicy: DecodePolicy
}
```

```swift
public enum DecodePolicy: Sendable, Hashable {
    case callerSuppliedRGBA
    case cgImage
    case cgImageSourceApplyOrientation
    case cgImageSourceRawOrientation
}
```

### 为什么要有 `DecodePolicy`

因为 Squoosh app 本身没有“自己解析 EXIF orientation 再旋转”的统一原生层；
它很大程度依赖浏览器 decode 后的像素语义。  
native 场景里不可能完美复刻浏览器行为，所以必须把这件事显式化。

### 建议默认

- 严格对齐层：`.callerSuppliedRGBA`
- Zipic 便利层：`.cgImageSourceApplyOrientation`

---

## 8.7 建议的实际 API 形态

```swift
public protocol SquooshJPEGEncoding {
    func encode(_ image: RGBAImage, options: SquooshMozJPEGOptions) throws -> EncodedJPEG
}

public protocol SquooshImageProcessing {
    func rotate(_ image: RGBAImage, by rotation: SquooshRotation) throws -> RGBAImage
    func resize(_ image: RGBAImage, options: SquooshResizeOptions) throws -> RGBAImage
}

public final class SquooshJPEGEncoder: SquooshJPEGEncoding {}
public final class SquooshPipeline {
    public func encode(_ image: RGBAImage, pipeline: SquooshPipelineOptions) throws -> EncodedJPEG
    public func encode(_ cgImage: CGImage, pipeline: SquooshPipelineOptions) throws -> EncodedJPEG
    public func encode(data: Data, uti: UTType?, pipeline: SquooshPipelineOptions) throws -> EncodedJPEG
}
```

### 返回值建议

```swift
public struct EncodedJPEG {
    public let data: Data
    public let diagnostics: JPEGDiagnostics
}
```

```swift
public struct JPEGDiagnostics: Sendable {
    public let width: Int
    public let height: Int
    public let outputByteCount: Int
    public let actualSubsampling: String
    public let progressive: Bool
    public let quantTableIndex: Int
    public let dcScanOptMode: Int
    public let metadataPolicy: JPEGMetadataPolicy
    public let copiedMarkers: [String]
}
```

### 为什么 diagnostics 必须要有

因为这套库不是“能压出来就行”，而是：

- 要验证是否和 Squoosh 一致
- 要给 Zipic 做回归测试
- 要排查“为什么某张图和 Squoosh 不一样”

没有 diagnostics，后面会很难查问题。

---

## 9. 核心实现要求

## 9.1 CMozJPEGSquooshCore

### 实现原则

不要做“普通 jpeglib wrapper”，而要尽量：

- **直接镜像 Squoosh 的 `mozjpeg_enc.cpp` 行为**
- 尤其是这些步骤必须一致：
  1. `jpeg_create_compress`
  2. `jpeg_mem_dest`
  3. `jpeg_set_defaults`
  4. `jpeg_set_colorspace`
  5. `jpeg_c_set_int_param(JINT_BASE_QUANT_TBL_IDX, ...)`
  6. `jpeg_c_set_bool_param(JBOOLEAN_OPTIMIZE_SCANS, TRUE)` if inherited / default
  7. `jpeg_c_set_int_param(JINT_DC_SCAN_OPT_MODE, 0)`
  8. `set_quality_ratings(...)`
  9. `jpeg_simple_progression(...)` when needed
  10. `jpeg_start_compress`
  11. `jpeg_write_scanlines`
  12. `jpeg_finish_compress`

### 必须额外明确的点

#### A. RGBA 输入
- 必须接受原始 RGBA8
- `in_color_space = JCS_EXT_RGBA`
- 不要改成 RGB 入口

#### B. `auto_subsample`
- 必须保留 MozJPEG `set_quality_ratings()` 的 subsampling heuristic
- 也就是说：
  - `<80` 倾向 `2x2`
  - `80~89` 倾向 `2x1`
  - `>=90` 倾向 `1x1`

#### C. `separate_chroma_quality`
- 必须保留 “最后解析的 quality 值会影响 auto-subsample heuristic” 这一行为

#### D. `dc_scan_opt_mode`
- 默认强制 `0`
- 当 `chroma_subsample > 2` 的极端手动模式下，应保留 Squoosh 的兼容性修正逻辑

#### E. arithmetic
- 第一阶段必须禁用
- 即使 Swift options 里保留字段，也应在 strict backend 中固定为不可用 / ignored with warning

---

## 9.2 Resize Core

Squoosh resize 不是一句“Lanczos3”就能替代的，它还有这些必须对齐的细节：

- 方法集：
  - `triangle`
  - `catrom`
  - `mitchell`
  - `lanczos3`
  - `hqx`
- `premultiply`
- `linearRGB`
- `fitMethod = contain/stretch`
- `contain` 的 offset 计算
- `Math.round` 带来的 crop rounding

### 推荐实现方式

#### 最优方案
- 直接 vendor / native 编译 Squoosh `codecs/resize` 对应实现
- 使用同版本 `resize` crate 0.5.5
- 通过 Rust -> C ABI -> Swift 暴露接口

#### 可接受方案
- 用等价 native 实现复刻同一算法

#### 不建议方案
- 直接换成：
  - `sips`
  - `NSImage`
  - `CoreImage Lanczos`
  - `vImageScale_ARGB8888`

这些方案未必差，但它们不是“Squoosh 对齐”。

---

## 9.3 Rotate Core

rotate 实现虽然简单，但也有两个要点：

1. 应在 **resize 之前** 执行
2. 只支持 `0 / 90 / 180 / 270`

### 说明

Squoosh app 里 rotate 是 preprocessor，resize 是 processor。  
如果顺序做反了：

- 宽高翻转时的 resize 值会不同
- contain 裁切行为也会不同

---

## 9.4 Metadata Core

这是 Zipic 需要、但 Squoosh 默认不做的一块。

### 关键认识

Squoosh 的 JPEG encode 路径本身：

- 从 `ImageData` 开始
- 最终 `new File([compressedData], ...)`
- 没有 marker copy 步骤

所以对齐 Squoosh 时：

> 默认行为应该是 **完全不保留 metadata**。

### 为什么不应继续依赖 jpegoptim

Zipic 当前用 `jpegoptim --strip-all`，本质上是：

- 先操作输入或临时文件
- 再让 MozJPEG CLI 工作

而在 native core 里：

- 如果默认输出本来就不写 marker
- 那就不需要额外 strip

因此：

> `jpegoptim` 在新 core 中不应该再作为默认依赖。  
> 它最多只应保留为 legacy fallback，而不应成为核心设计的一部分。

### Metadata 模块建议职责

1. 解析 JPEG marker
2. 识别：
   - APP0 / JFIF
   - APP1 / EXIF / XMP
   - APP2 / ICC
   - APP13 / IPTC
   - COM
3. 按 policy 决定保留、剔除、重写
4. 在编码结果上重新注入 marker

### 必须仔细说明的边界

#### A. JPEG 输入 preserve
- 最容易做
- 直接从原 JPEG 复制 marker 最稳

#### B. PNG / TIFF / HEIC -> JPEG preserve
- 难度明显更高
- 因为是“元数据映射”，不是“marker 原样复制”
- 应作为扩展模式，而不是 strict parity 模式

#### C. Orientation
- 如果 decode 阶段已经应用 orientation，就不能再把原 EXIF orientation 原样写回
- 否则会二次旋转语义错误

#### D. ICC
- 在 preserve 色彩时优先级很高
- 这部分应早于“完整保留 EXIF”的优先级

---

## 10. 细节风险清单（必须在设计里写清楚）

## 10.1 输入解码差异

### 风险

Squoosh app 使用浏览器解码 / worker 解码，native 用 ImageIO。  
同一张图片解码成 RGBA 时，可能因以下因素出现差异：

- orientation
- colorspace transform
- gamma
- alpha
- browser canvas 语义

### 结论

严格对齐基准应定义为：

- **同一组 RGBA fixture**，而不是同一组源文件。

---

## 10.2 透明图转 JPEG

### 风险

Squoosh 对 JPEG 的输入是 RGBA，但 JPEG 本身不保留 alpha。  
如果源图有透明通道：

- 最终背景色语义依赖上游像素准备方式
- 透明区域的 RGB 值可能影响最终结果

### 设计要求

- strict encoder 层：
  - 不做隐式 flatten
  - 直接消费 RGBA，保持与 Squoosh 一致的最小假设
- pipeline 层：
  - 必须把 alpha policy 显式化
  - 如果 Zipic 需要白底/黑底/棋盘底，应作为产品层策略，而不是 core 默认行为

---

## 10.3 Resize 的 rounding

`contain` 不是简单按比例缩放，它还涉及：

- 裁切区域计算
- 四舍五入策略

Squoosh 用的是：

- `getContainOffsets(...)`
- 再 `Math.round(sx/sy/sw/sh)`

如果 native 层改成：

- `floor`
- `ceil`
- 或 CoreGraphics 自己的内部 rounding

结果就可能偏掉一列/一行像素。

---

## 10.4 Progressive 与 optimize

- `progressive = true`
- `optimize_coding = true`
- `optimize_scans = true`

这三者在 MozJPEG 中不是完全独立的。  
实现层不能只盯着 UI 选项，而忽略 hidden defaults。

---

## 10.5 auto subsample 与 separate chroma quality 联动

这是必须在文档里写死的坑：

- 当 `separate_chroma_quality = true` 且 `auto_subsample = true` 时
- `set_quality_ratings()` 用最后解析的 quality 值影响 subsample heuristic

这会导致：

- 明明主 quality 不高
- 但 chroma_quality 高时，实际 subsampling 升级
- 文件体积大幅上升

如果实现时没保留这个行为，结果会和 Squoosh 偏离。

---

## 11. 仓库组织建议

建议把这个库先独立成单独 package / repo，而不是直接揉进 Zipic 主工程。

### 推荐结构

```text
SquooshJPEGKit/
  Vendor/
    mozjpeg-3.3.1/
    squoosh-mozjpeg-enc-port/
    squoosh-resize/
    squoosh-hqx/ (optional)
  Sources/
    CMozJPEGSquooshCore/
      include/
      mozjpeg_shim.c
      squoosh_port.cpp
    CSquooshResizeCore/
      include/
      resize_ffi.c
      rust static libs
    SquooshJPEGKit/
      RGBAImage.swift
      SquooshMozJPEGOptions.swift
      SquooshResizeOptions.swift
      JPEGMetadataPolicy.swift
      SquooshPipeline.swift
      JPEGDiagnostics.swift
  Tests/
    Fixtures/
    EncoderParityTests/
    ResizeParityTests/
    MetadataPolicyTests/
```

### 为什么推荐独立仓库/包

因为这套库后面很可能变成：

- Zipic 的 JPEG 核心
- 未来其他工具/服务的 JPEG 核心
- 一套可以长期维护的压缩基线

---

## 12. 实施阶段规划

## Phase 1：严格编码器对齐（必须先做）

目标：

- `encode(rgba:options:)` 跑通
- MozJPEG 3.3.1 native backend 对齐 Squoosh
- 建立第一批 encoder parity fixtures

交付：

- `CMozJPEGSquooshCore`
- `SquooshMozJPEGOptions`
- `SquooshJPEGEncoder`
- `JPEGDiagnostics`

### Phase 1 完成标准

- 默认参数下能稳定输出 JPEG
- 能跑样本图和 Squoosh 对照
- 已确认 `dc_scan_opt_mode = 0`、quant_table、auto_subsample 等关键行为一致

---

## Phase 2：Resize / Rotate 对齐

目标：

- 复刻 Squoosh 的 rotate / resize 行为
- 建立像素级对照测试

交付：

- `CSquooshResizeCore`
- `SquooshResizeOptions`
- `SquooshRotation`
- `SquooshPipeline.encode(RGBAImage, pipeline:)`

### Phase 2 完成标准

- `lanczos3 / catrom / mitchell / triangle / hqx` 工作正常
- `premultiply / linearRGB / contain` 行为已验证
- rotate 与 resize 顺序与 Squoosh 一致

---

## Phase 3：Metadata 模块

目标：

- 在不破坏 strict parity 默认的前提下，实现 Zipic 需要的 metadata 策略

交付：

- `JPEGMetadataPolicy`
- marker parser/writer
- preserveICC / preserveSafe / preserveAllRecognized

### Phase 3 完成标准

- `squooshDropAll` 默认完全可用
- JPEG 输入的 marker copy 可控稳定
- orientation / ICC 处理边界说明完整

---

## Phase 4：Package 稳定化与 Zipic 接入准备

目标：

- 并发安全
- 压缩性能/内存稳定
- 错误模型稳定
- build 输出稳定

交付：

- 完整文档
- fixture 工具
- version pinning
- CI 对照测试

---

## 13. 测试与验证要求

## 13.1 测试必须分层

### A. Encoder Parity Tests
输入：
- 固定 RGBA fixture
- 固定 Squoosh MozJPEG options

比较：
- 输出 bytes
- file size
- quant tables
- sampling factors
- progressive scans

### B. Resize Parity Tests
输入：
- 固定 RGBA fixture
- 固定 resize options

比较：
- 输出 RGBA byte diff
- PSNR/SSIM（作为辅助）

### C. Metadata Policy Tests
输入：
- JPEG with EXIF/ICC/XMP/COM
- PNG with ICC
- HEIC/TIFF with metadata

比较：
- output markers
- orientation correctness
- color profile retention

### D. End-to-End Pipeline Tests
输入：
- Zipic 常见图片类型

比较：
- 新库输出
- 当前 Zipic CLI 输出
- Squoosh 参考输出

---

## 14. 最终建议

## 14.1 是否值得先做这个库？

**值得，而且应该先做。**

但要注意：

- 不是做一个“普通 MozJPEG wrapper”
- 而是做一个：
  - **Squoosh-compatible**
  - **版本冻结**
  - **行为冻结**
  - **可验证**
  的 JPEG core

## 14.2 最重要的三条原则

### 原则 1：严格对齐层必须从 RGBA 开始
这决定了后续一切验证是否成立。

### 原则 2：默认行为必须先等于 Squoosh，而不是等于 Zipic 旧逻辑
否则永远会陷在“兼容旧行为”和“追 Squoosh”之间摇摆。

### 原则 3：metadata preserve 必须作为扩展策略，而不是默认行为
Squoosh 默认就是不保留 marker。  
如果这点不在设计里写清楚，后面结果会越来越乱。

---

## 15. 一句话结论

> **这套库完全值得做，而且如果目标是尽可能贴近 Squoosh，它比继续堆 CLI 更接近最终正确方向。**  
> 但前提是：
> - 锁死 **MozJPEG 3.3.1**；
> - 锁死 **Squoosh 默认值与隐藏默认值**；
> - 锁死 **RGBA 输入模型**；
> - 把 **resize / rotate / metadata policy** 一并纳入设计；
> - 用 fixture 和 diagnostics 去证明“真的对齐了”。
