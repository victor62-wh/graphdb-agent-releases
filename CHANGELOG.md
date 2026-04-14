# Changelog

graphdb-agent 更新日志。重点标注集成方需要关注的变更。

格式说明：
- **[集成方需关注]** — 集成方可能需要修改代码或配置
- 其余为内部改进，升级二进制即可生效

---

## v0.4.0 (2026-04-14)

### Graph Panel: 可配置属性显示

**[集成方需关注]** 后端 tool result 新增可选字段 `_fieldAliases`，可控制前端属性显示名。

#### 新功能

- **属性别名 (Field Aliases)**: tooltip 和节点详情中的属性名可显示本地化别名，而非原始字段名
- **属性可见性 (Visible Fields)**: 齿轮弹窗新增 checkbox 区域，用户可按 `_label` 类型选择显示/隐藏哪些属性
- **URL 预设别名**: 支持 `?fieldAliases=<JSON>` URL 参数预设基础别名

#### 集成方接入方式

**方式一：后端 tool result 附带别名（推荐）**

在返回图数据的 tool result 中添加 `_fieldAliases` 字段：

```json
{
  "_graph": [...],
  "_fieldAliases": {
    "name": { "zh-CN": "姓名", "en": "Name" },
    "age": { "zh-CN": "年龄", "en": "Age" }
  }
}
```

前端自动提取并增量合并，无需额外配置。

**方式二：URL 参数预设**

iframe 嵌入时通过 URL 参数传入基础别名：

```
http://host:port/?fieldAliases={"name":{"zh-CN":"姓名","en":"Name"}}
```

优先级：tool result 中的别名 > URL 参数别名 > 原始字段名。

**不做任何改动时**：行为与 v0.3.0 完全一致（向后兼容）。

---

## v0.3.0 (2026-04-13)

### Graph Panel 多布局 + 交互增强

- 多布局切换（力导向/树形/辐射/环形/网格）
- 节点 hover tooltip，显示所有属性
- 齿轮弹窗：配置每种 `_label` 类型在图上显示哪个字段作为节点文字
- 点击节点弹出详情卡片，支持"展开关联"按钮自动发起查询

#### 集成方接入方式

**[集成方需关注]** 图数据格式要求节点带 `_type:"node"` + `_id` + `_label`，边带 `_type:"edge"` + `_id` + `_from` + `_to` + `_label`。也兼容 KG360 的 `id/label/type/source/target` 格式。

---

## v0.1.0 (2026-04-12)

### 首个独立发行版

- 独立 HTTP server 二进制，内嵌 Web UI
- 三面板布局：Chat / Graph / Result
- SSE 流式对话
- 远程 tool 注册 API (`POST/DELETE/GET /api/v1/tools`)
- URL 参数配置：`?theme=dark&lang=en&compact=true&panels=chat,graph,result`
- `install.sh` 一键安装/升级脚本

**[集成方需关注]** 其他系统不能从源码构建（主仓库为 private），需通过 `install.sh` 安装二进制：
```bash
curl -fsSL https://raw.githubusercontent.com/victor62-wh/graphdb-agent-releases/main/install.sh | bash
```
