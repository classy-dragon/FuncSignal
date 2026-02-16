<p align="center">
  <img src="https://github.com/classy-dragon/FuncSignal/blob/main/FuncSignal.png?raw=true" width="100" alt="FuncSignal Logo">
</p>
<h1 align="center">FuncSignal</h1>
<p align="center">
  <a href="https://luau-lang.org/"><img src="https://img.shields.io/badge/Made%20With%20Luau-6680b4" alt="Made With Luau"></a>
  <a href="https://github.com/classy-dragon/FuncSignal"><img src="https://img.shields.io/badge/Signal%2FEvent%20Handler-5657be" alt="Signal Handler"></a>
  <img src="https://img.shields.io/badge/Platform-Roblox-white" alt="Platform">
  <img src="https://img.shields.io/badge/Version-1.2.0-blue" alt="Version">
</p>

### **FuncSignal** is a production-grade event system for Luau, benchmarked at **258x faster** than standard Roblox BindableEvents.
---
## ➡️ Quick Links:
* ❓ [Why FuncSignal?](#-why-funcsignal)
* 🔅 [Key Features](#-key-features)
* ⚙️ [Flexible Runtimes](#frt)
* 🛰️ [Proxy Function Arguments (Advanced)](#pfa)
* 📊 [Performance Benchmarks](#pc)
* ⚠️ [Good Practices](#gp)
* 📦 [Installation](#-installation)
* 🛠 [Usage Examples](#-usage-examples)
* 📜 [Source Code](https://github.com/classy-dragon/FuncSignal/blob/main/src/FuncSignal.luau)
---

## ❓ Why FuncSignal:

Most signal libraries force a trade-off between being "fast" or "feature-rich." FuncSignal delivers both by introducing architectural patterns usually reserved for low-level engine code, optimized for Native Luau.

### 🔅 Key Features:
* **Native-Optimized Execution:** Tailored for the Luau VM to ensure minimal overhead during high-frequency dispatch cycles.
* **Flexible Runtimes:** Switch execution strategies on the fly. Full support for `NATIVE`, `DEFERRED`, `THREADED`, and `PCALL`.
* **Middleware Interceptors:** A global "hook" system that allows you to modify, sanitize, or validate data *before* it reaches any listener.
* **Proxy Multiplexing:** Branch a single dispatcher into multiple "Proxy Groups." This is perfect for decoupling UI, Audio, and Physics logic while maintaining an single connection.
* **Snapshot Safety:** Uses memory-safe snapshots to prevent re-entrancy bugs (errors caused by disconnecting listeners while the signal is firing).
  
---

<a name="frt"></a>
## ⚙️ Flexible Runtimes:

| Runtime | Style | Description | Best For... |
| :--- | :--- | :--- | :--- |
| **`NATIVE`** | **Sync** | Executes immediately on the same thread. | Core logic & high-speed math. |
| **`DEFERRED`** | **Async** | Executes at the end of the current engine step. | UI updates & state replication. |
| **`THREADED`** | **Spawn** | Wraps each listener in `task.spawn`. | Independent, heavy processes. |
| **`PCALL`** | **Safe** | Wraps execution in a protected call. | 3rd-party code or unstable plugins. |

---

<a name="pfa"></a>
## 🛰️ Proxy.Function.Arguments (Advanced):

PFA allows you to branch a single dispatcher into specialized groups. This is ideal for complex systems like **Monitors** or **Loggers** where you need to intercept data, transform it, and notify specific observers.

### Why use it?
* **Decoupling:** Keep your UI logic completely separate from your core Game logic.
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

<a name="pc"></a>
## 📊 Performance Context

FuncSignal's performance advantage scales with data complexity.
	**Primitive Data (Number/String):** ~50x - 100x faster than BindableEvents.
	**Complex Data (Large Tables):** Up to 26,000x faster.

**The Reason:** The Reason: *Roblox* BindableEvents perform a "Deep Copy" of all arguments to cross the **C++** bridge. FuncSignal remains entirely within the Luau VM, passing references via the Stack Pointer.

---

<a name="gp"></a>
## ⚠️ Good Practices:
* Do NOT Yield in Native: `FireNative` is synchronous. To maintain performance, avoid using task.wait() in these listeners.
* Use Proxies for UI: I recommend the DEFERRED runtime for UI updates to ensure they don't block critical game logic.
* Safe Cleanup: Always use `:Destroy()` to ensure the Luau Garbage Collector can reclaim memory from any unused signals.
* FireHardware: For scenarios where every microsecond counts, FireHardware bypasses the Interceptor pipeline and Runtime headers to provide the rawest dispatch loop possible. Use this only when you are certain your data does not need sanitization.

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
> If you are building a simple UI button, any signal library will work. But if you are building an RPG with massive inventories, a simulator with thousands of moving parts, or a global state system, the performance gain of FuncSignal is the difference between a smooth 60 FPS and a lagging game.
---
*🎩*
