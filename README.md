# 🔷 FuncSignal
[![Made With Luau](https://img.shields.io/badge/Made%20With%20Luau-6680b4)](https://luau-lang.org/) [![Made With Luau](https://img.shields.io/badge/Signal%2FEvent%20Handler-5657be)](https://github.com/classy-dragon/FuncSignal) ![Platform](https://img.shields.io/badge/Platform-Roblox-white) ![Version](https://img.shields.io/badge/Version-1.0.0-blue)
### **FuncSignal** is a production-grade event system for Luau, benchmarked at **258x faster** than standard Roblox BindableEvents.
---
## ➡️ Quick Links:
* ❓ [Why FuncSignal?](#-why-funcsignal)
* 🔅 [Key Features](#-key-features)
* 📊 [Performance Benchmarks](#-performance-benchmarks)
* ⚠️ [Good Practices](#gp)
* 🛠 [Usage Examples](#-usage-examples)
* 📜 [Source Code](https://github.com/classy-dragon/FuncSignal/blob/main/FuncSignal.luau)
---

## ❓ Why FuncSignal:

Most signal libraries focus on either being "fast" or "feature-rich." FuncSignal delivers both by introducing architectural patterns usually reserved for low-level engine code.

### 🔅 Key Features:
* **Native-Optimized Execution:** Optimized for the Luau VM to ensure minimal overhead during high-frequency dispatch cycles.
* **Flexible Runtimes:** Switch execution strategies on the fly. Support for `NATIVE`, `DEFERRED`, `THREADED`, `STEPPED`, and `PCALL`.
* **Middleware Interceptors:** A global "hook" system that allows you to modify, sanitize, or validate data *before* it reaches any listener.
* **Proxy Multiplexing:** Branch a single dispatcher into multiple "Proxy Groups." Perfect for decoupling UI, Audio, and Physics logic while maintaining a single source of truth.
* **Snapshot Safety:** Uses memory-safe snapshots to prevent re-entrancy bugs (errors caused by disconnecting listeners while the signal is firing).

---

## 📊 Performance Benchmarks:
*Tested with 500 listeners and 1,000 fire cycles in a live Server environment.*

| Implementation | Execution Time | Speed Factor |
| :--- | :--- | :--- |
| **FuncSignal (Native)** | **0.8497 ms** | **1.0x (Reference)** |
| **BindableEvent** | **219.4698 ms** | **258.29x Slower** |

---

<a name="gp"></a>
## ⚠️ Good Practices:

* **Do NOT Yield in Native:** `FireNative` is synchronous. Avoid `task.wait()` in these listeners.
* **Use Proxies for UI:** Always use the `DEFERRED` runtime for UI updates to ensure they don't block game logic.
* **Safe Cleanup:** Use `:Destroy()` to ensure the Luau Garbage Collector can reclaim memory from unused signals.



---
## 🛠 Usage Examples:

### 1. The Global Interceptor (Middleware)
Ensure your data is always formatted correctly before it hits your systems.
```luau
local FuncSignal = require("./FuncSignal")
local Dispatcher = FuncSignal:CreateDispatcher()

-- Force all outgoing string data to be uppercase and wrapped in a table
Dispatcher:SetCustomFireARGSIntercept(function(data: string)
    return { data:upper() }
end)

Dispatcher:Connect(print)
Dispatcher:FireNative("hello") -- Output: HELLO
```
### 2. OOP, Events/Signals
Letting other modules to be able to hook into your module easy!
```luau
local SimpleLogger = {}
local FuncSignal = require("./FuncSignal")

export type Logger = {
	Logs:{string},
	PushLog:(self:Logger,Log:string)->(),
	RemoveLog:(self:Logger,Log:string)->(),
	OnChanged:FuncSignal.Dispatcher
}

local LoggerClass = {} :: Logger & {__index:Logger}
LoggerClass.__index = LoggerClass

function SimpleLogger:CreateLogger()
	local Logger = {
		Logs={},
		OnChanged=FuncSignal:CreateDispatcher()
	} :: Logger
	setmetatable(Logger,LoggerClass)
	return Logger
end

function LoggerClass:PushLog(NewLog)
	table.insert(self.Logs,NewLog)
  -- Using FireNative ensures the log is processed immediately
  -- before the rest of the code continues.
	self.OnChanged:FireNative(true,NewLog)
end

function LoggerClass:RemoveLog(Log)
	local Index = table.find(self.Logs,Log)
	if Index then
		table.remove(self.Logs,Index)
		self.OnChanged:FireNative(false,Log)
	end
end

return SimpleLogger
```
---
