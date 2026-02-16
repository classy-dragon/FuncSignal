# 🔷 FuncSignal
[![Made With Luau](https://img.shields.io/badge/Made%20With%20Luau-6680b4)](https://luau-lang.org/) [![Made With Luau](https://img.shields.io/badge/Signal%2FEvent%20Handler-5657be)](https://github.com/classy-dragon/FuncSignal) ![Platform](https://img.shields.io/badge/Platform-Roblox-white) ![Version](https://img.shields.io/badge/Version-1.0.0-blue)
### **FuncSignal** is a production-grade event system for Luau, benchmarked at **258x faster** than standard Roblox BindableEvents.
---
## ➡️ Quick Links:
* ❓ [Why FuncSignal?](#-why-funcsignal)
* 🔅 [Key Features](#-key-features)
* ⚙️ [Flexible Runtimes](#FRT)
* 🛰️ [Proxy Function Arguments (Advanced)](#PFA)
* 📊 [Performance Benchmarks](#-performance-benchmarks)
* ⚠️ [Good Practices](#gp)
* 📦 [Installation](#-installation)
* 🛠 [Usage Examples](#-usage-examples)
* 📜 [Source Code](https://github.com/classy-dragon/FuncSignal/blob/main/src/FuncSignal.luau)
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

<a name="FRT"></a>
## ⚙️ Flexible Runtimes:

| Runtime | Style | Description | Best For... |
| :--- | :--- | :--- | :--- |
| **`NATIVE`** | **Sync** | Executes immediately on the same thread. | Core logic & high-speed math. |
| **`DEFERRED`** | **Async** | Executes at the end of the current engine step. | UI updates & state replication. |
| **`THREADED`** | **Spawn** | Wraps each listener in `task.spawn`. | Independent, heavy processes. |
| **`STEPPED`** | **Sync** | Synchronizes with the `Heartbeat` signal. | Frame-by-frame visual updates. |
| **`PCALL`** | **Safe** | Wraps execution in a protected call. | 3rd-party code or unstable plugins. |

---

<a name="PFA"></a>
## 🛰️ Proxy.Function.Arguments (Advanced):

PFA allows you to branch a single dispatcher into specialized groups. This is perfect for complex systems like **Monitors** or **Loggers** where you want to intercept data, modify it, and then notify specific observers.

### Why use it?
* **Decoupling:** Keep your UI logic separate from your Game logic.
* **Automatic Logging:** Use Interceptors to log every signal fire without manually adding `print()` to every script.
* **Data Transformation:** Sanitize or format data (like JSON encoding) once before it hits multiple listeners.

### Example: The Signal Monitor
In this pattern, we use a metatable to detect when data changes and automatically fire a signal. We also intercept the main signal to log its arguments automatically.

```luau
-- Intercepting and Logging via Proxy Logic
SignalMonitor.ExampleFS:SetCustomFireARGSIntercept(function(...)
    -- Log the arguments to a table before passing them to listeners
    table.insert(SignalMonitor.Logs, "Fired with: " .. HttpService:JSONEncode({...}))
    return {...}
end)
```

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

## 📦 Installation:

### 1. Wally:
Add the following line to your `wally.toml` file and run `wally install`:
```toml
FuncSignal = "classy-dragon/funcsignal@1.0.0"
```

### 2. Rojo:
If you are using Rojo, you can simply include this repository as a submodule or copy the src folder into your project's shared or packages directory. Ensure your default.project.json points to the source:
```json
"FuncSignal": {
  "$path": "path/to/src/FuncSignal.luau"
}
```

### 3. Manual Installation:
For developers who prefer working directly in Roblox Studio:
  1.  **Download** the [FuncSignal.luau](https://github.com/classy-dragon/FuncSignal/main/src/FuncSignal.luau) file
  2.  **Create** a new ModuleScript in  ReplicatedStorage *(or where ever you want to use it)*
  3.  **Rename** the ModuleScript to FuncSignal
  4.  **Paste** the source code into the script

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
### 3. OOP, Easy Signal Monitoring:
You can intercept the fire events and alter/format/etc with the func arguments.
```luau
--!strict
local SimpleSignalMonitor = {}
local FuncSignal = require("./FuncSignal")

export type SignalMonitor = {
	Logs:{string},
	ExampleFS:FuncSignal.Dispatcher,
	LogAdded:FuncSignal.Dispatcher,
	GetLogs:(self:SignalMonitor)->({string}),
	Send:(self:SignalMonitor,...any) -> ()
}

local SignalMonitorClass = {} :: SignalMonitor & {__index:SignalMonitor}
SignalMonitorClass.__index = SignalMonitorClass

function SimpleSignalMonitor:CreateSignalMonitor()
	local SignalMonitor = {
		ExampleFS=FuncSignal:CreateDispatcher(),
		LogAdded=FuncSignal:CreateDispatcher()
	} :: SignalMonitor
	setmetatable(SignalMonitor,SignalMonitorClass)
	
	SignalMonitor.Logs=setmetatable({},{
		__newindex=function(T,N,V)
			rawset(T,N,V)
			SignalMonitor.LogAdded:FireDeferred(V)
		end
	})
	
	SignalMonitor.ExampleFS:SetCustomFireARGSIntercept(function(...)
		table.insert(SignalMonitor.Logs,"ExampleFS has been Fired, Function Arguments:"..game:GetService("HttpService"):JSONEncode({...}))
		return {...}
	end)
	
	return SignalMonitor
end

function SignalMonitorClass:Send(...)
	self.ExampleFS:Fire(...)
end

function SignalMonitorClass:GetLogs()
	return self.Logs
end

return SimpleSignalMonitor
```
---
