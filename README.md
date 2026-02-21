<p align="center">
  <img src="https://github.com/classy-dragon/FuncSignal/blob/main/FuncSignal.png?raw=true" width="100" alt="FuncSignal Logo">
</p>
<h1 align="center">FuncSignal v2.0.0</h1>
<p align="center">
  <a href="https://luau-lang.org/"><img src="https://img.shields.io/badge/Made%20With%20Luau-6680b4" alt="Made With Luau"></a>
  <a href="https://luau.org/types/object-oriented-programs/"><img src="https://img.shields.io/badge/Luau - Object%2EOriented%2EProgramming-3f6f97" alt="Made With Luau - OOP"></a>
  <a href="https://github.com/classy-dragon/FuncSignal"><img src="https://img.shields.io/badge/Signal%2FEvent%20Handler-5657be" alt="Signal Handler"></a>
  <img src="https://img.shields.io/badge/Platform-Roblox-white" alt="Platform">
  <img src="https://img.shields.io/badge/Version-2.0.0-blue" alt="Version">
</p>

### **FuncSignal** is a production-grade event system for Luau, benchmarked at over **8x faster** than BindableEvents for primitives and up to **26,000x faster** for complex data. Version 2.0.0 introduces **Parallel Execution**, **Connection Pooling**, and advanced **Fire Filtering**.

---
## ➡️ Quick Links:
* ⚛️ [Why Should I Use FuncSignal?](#whyfs)
* 🔅 [Key Features](#-key-features)
* ⚙️ [Flexible Runtimes](#frt)
* 🛡️ [Fire Filters](#ff)
* 💽 [Proxy Function Arguments](#pfa)
* 📊 [Performance Context](#pc)
* ⚠️ [Good Practices](#gp)
* 📦 [Installation](#-installation)
* 🛠 [Usage Examples](#-usage-examples)
* ↗️ [Migration From GoodSignal](#gsm)
* 📜 [Source Code](https://github.com/classy-dragon/FuncSignal/blob/main/src/FuncSignal.luau)
---

<a name="whyfs"></a>
## ⚛️ Why should *i* use *FuncSignal?*:

Most signal libraries force a trade-off between simplicity and speed. FuncSignal delivers both by utilizing **Data-Oriented Design (DOD)** patterns and **Connection Pooling**.

### ⛓️‍💥 Break the "C++ Bridge" Bottleneck
Standard Roblox **BindableEvents** "Deep Copy" data between Luau and C++.
* **The Cost:** Massive overhead (300ns - 600ns+) per fire.
* **The FuncSignal Edge:** We stay entirely within the Luau VM, passing memory references via the Stack Pointer. This makes our `HARDWARE` runtime significantly faster than native engine solutions.

### 🏊 Connection Pooling (New in **v2.0.0**)
FuncSignal now features an internal pooling system. When a connection is disconnected, it isn't just trashed; it's cleaned and stored for reuse. This drastically reduces GC pressure in systems with high connection/disconnection churn.

### 🔅 Key Features:
* **Zero-Allocation Dispatch:** Firing a signal costs near-zero memory.
* **Parallel Support:** `FireParallel` allows you to execute listeners across multiple CPU cores natively.
* **Fire Filters:** Attach logic to your signals to conditionally block dispatches before they even hit the runtime headers.
* **Middleware Interceptors:** Modify or sanitize data globally *before* it reaches any listener.
* **O(1) Disconnection:** Uses swap-with-last array logic to ensure instantaneous disconnection.

---

<a name="frt"></a>
## ⚙️ Flexible Runtimes:
| Runtime | Style | Description | Best For... |
| :--- | :--- | :--- | :--- |
| **`NATIVE`** | **Sync** | Executes immediately on the **same** thread. | Core logic & high-speed math. |
| **`DEFERRED`** | **Async** | Executes at the end of the current engine step. | UI updates & state replication. |
| **`THREADED`** | **Spawn** | Wraps each listener in `task.spawn`. | Independent, heavy processes. |
| **`PARALLEL`** | **Multi** | Executes connections in Parallel (Actor-safe). | Heavy compute/physics tasks. |
| **`PCALL`** | **Safe** | Wraps execution in a protected call. | 3rd-party code or unstable plugins. |
| **`HARDWARE`**| **Raw** | Bypasses all headers/interceptors for raw speed. | Maximum performance loops. |
| **`STEPPED`** | **Debug** | Executes per step (waits per step). | Debugging execution flow. |

---

<a name="ff"></a>
## 🛡️ Fire Filters:
New in **v2.0.0**, the **FireFilter** allows you to "gatekeep" your signals. If a filter layer returns `false`, the entire dispatch is cancelled for that fire.

```luau
local Filter = Dispatcher.FireFilter
Filter:Import(function(Data)
    return Data ~= nil -- Prevent firing if data is nil
end)
```

---

<a name="pfa"></a>
## 💽 Proxy Function Arguments:

PFA allows you to branch a single dispatcher into specialized groups. This is ideal for complex systems like **Monitors** or **Loggers** where you need to intercept data, transform it, and notify specific observers.

### Why use it?
* **Decoupling:** Keep your UI logic completely separate from your core Game logic.
* **Automatic Logging:** Use Interceptors to log every signal fire without manually adding `print()` to every script.
* **Data Transformation:** Sanitize or format data (like JSON encoding) once before it hits multiple listeners.

### Example: The Signal Monitor
In this pattern, we use a metatable to detect when data changes and automatically fire a signal. We also intercept the main signal to log its arguments automatically.

```luau
-- Intercepting and Logging via Proxy Logic
SignalMonitor.ExampleFS:SetCustomIntercept(function(...)
    -- prints any fire args!
    print(...)
    return ...
end)
```

---

<a name="pc"></a>
## 📊 Performance Context
FuncSignal's performance advantage scales with data complexity.
* **Primitive Data (Number/String):** Roughly **8x - 10x faster** than BindableEvents.
* **Complex Data (Large Tables):** Up to **26,000x faster**.

**The Reason:** Roblox `BindableEvents` perform a "Deep Copy" of all arguments. FuncSignal remains entirely within the Luau VM, passing references via the Stack Pointer.

---

<a name="gp"></a>
## ⚠️ Good Practices:
* **Do NOT Yield in Native:** `FireNative` and `FireHardware` are synchronous. Avoid `task.wait()` in these listeners to prevent blocking.
* **Avoid Self-Connection:** Never connect a dispatcher to itself inside a listener; this will create a memory leak or a loop.
* **Infinite Loops:** Firing a signal inside its own connection will cause a C-stack overflow.
* **Cleanup:** Always use `:Destroy()` when finished. It ensures the FireFilter and all internal tables are cleared for the Garbage Collector.
* **Preloading:** Use `FuncSignal:PreloadConnectionsToPool(X)` during loading screens to warm up the pool and avoid allocation spikes during gameplay.
* **FireHardware:** Use this when every nanosecond counts. It bypasses the Interceptor pipeline and provides the rawest dispatch loop possible.
* **Use Proxies for UI:** I recommend the `DEFERRED` runtime for UI updates to ensure they don't block critical game logic frames.

## 📦 Installation:

### Wally:
```toml
FuncSignal = "classy-dragon/funcsignal@2.0.0"
```
### Rojo:
If you are using Rojo, you can simply include this repository as a submodule or copy the src folder into your project's shared or packages directory. Ensure your default.project.json points to the source:
```json
"FuncSignal": {
  "$path": "path/to/src/FuncSignal.luau"
}
```

### Roblox Package Installation:
1. Download [FuncSignal.RBXM](https://github.com/classy-dragon/FuncSignal/releases/tag/RBXM).
2. Insert The RBXM into the project. (Insert From Roblox Model)

### Manual Installation:
1. Download [FuncSignal.luau](https://github.com/classy-dragon/FuncSignal/main/src/FuncSignal.luau).
2. Create a `ModuleScript` named **FuncSignal**.
3. Paste the source code.

---

## 🛠 Usage Examples:

### Strict Typing
FuncSignal v2.0.0 is built with full type safety in mind.
```luau
local FuncSignal = require("./FuncSignal")
local Dispatcher = FuncSignal:CreateDispatcher() :: FuncSignal.Dispatcher<number>

Dispatcher:Connect(function(Value: number)
    print(Value + 10) -- Autocomplete and type checking enabled
end)

Dispatcher:FireNative(50)
```
### Parallel Dispatching
Offload heavy math to other threads easily.
```luau
local Dispatcher = FuncSignal:CreateDispatcher()
Dispatcher:Connect(function(Data)
    -- This runs in a de-synchronized state!
    print("Computing in parallel:", Data)
end)

-- Fire in parallel, resyncing after completion
Dispatcher:FireParallel(true, "Complex Physics Data")
```

### Global Interceptor (Middleware)
Format outgoing data globally.
```luau
local Dispatcher = FuncSignal:CreateDispatcher() :: FuncSignal.Dispatcher<string>

Dispatcher:SetCustomIntercept(function(Input: string)
	return Input:upper()
end)

Dispatcher:Connect(print) 
Dispatcher:FireNative("hello") -- Output: HELLO
```

### Linked RBX Signals
Conveniently bridge engine events into the FuncSignal ecosystem.
```luau
local Bridge = FuncSignal:CreateDispatcherLinkedRBX(game:GetService("RunService").Heartbeat)
Bridge.Dispatcher:Connect(function(DeltaTime)
    -- Your logic here
end)
```
### Objects Based (OOP/DOD), Events/Signals
Letting other modules hook into your module easily.
```luau
local SimpleLogger = {}
local FuncSignal = require("./FuncSignal")

export type Logger = {
	Logs:{string},
	PushLog:(self:Logger, Log:string)->(),
	RemoveLog:(self:Logger, Log:string)->(boolean),
	OnChanged:FuncSignal.PublicDispatcher<boolean,string>,
	_PrivateOnChanged:FuncSignal.Dispatcher<boolean,string>
}
local LoggerClass = {} :: Logger & {__index:Logger}
LoggerClass.__index=LoggerClass

function SimpleLogger:CreateLogger()
	local _OnChanged = FuncSignal:CreateDispatcher() :: FuncSignal.Dispatcher<boolean,string>
	local Logger = {
		Logs={},
		_PrivateOnChanged=_OnChanged,
		OnChanged = _OnChanged.PublicDispatcher
	} :: Logger
	setmetatable(Logger,LoggerClass)
	return Logger
end

function LoggerClass:PushLog(NewLog)
	table.insert(self.Logs, NewLog)
	self._PrivateOnChanged:FireNative(true, NewLog)
end

function LoggerClass:RemoveLog(RemoveLog)
	local Index = table.find(self.Logs,RemoveLog)
	if Index then
		table.remove(self.Logs,Index)
		self._PrivateOnChanged:FireNative(false, RemoveLog)
	end
	return Index~=nil
end

return SimpleLogger
```
### OOP, Easy Signal Monitoring:
Intercept fire events to alter or format arguments on the fly.
```luau
local SimpleSignalMonitor = {}
local FuncSignal = require("./FuncSignal")

function SimpleSignalMonitor:CreateSignalMonitor()
	local SignalMonitor = {
		MonitoredDispatcher = FuncSignal:CreateDispatcher(),
		OutputLogsDispatcher = FuncSignal:CreateDispatcher() :: FuncSignal.Dispatcher<>,
		Logs = {}
	}

	-- This hook runs every time ExampleFS:Fire() is called
	SignalMonitor.MonitoredDispatcher:SetCustomIntercept(function(...)
		local encoded = game:GetService("HttpService"):JSONEncode({...})
		table.insert(SignalMonitor.Logs, "Log: " .. encoded)
		return ...
	end)
	
	SignalMonitor.OutputLogsDispatcher:Connect(function()
		print(SignalMonitor.Logs)
	end)

	return SignalMonitor
end

return SimpleSignalMonitor
```
---
<a name="gsm"></a>
# ↗️ Migration Guide: GoodSignal → FuncSignal

## 1. The Core Constructor
| Feature | GoodSignal | FuncSignal |
| :--- | :--- | :--- |
| **Constructor** | `GoodSignal.new()` | `FuncSignal:CreateDispatcher()` |
| **Bulk Disconnect**| `Signal:DisconnectAll()`| `Dispatcher:DisconnectAll()` |
| **Cleanup** | `Signal:Destroy()` | `Dispatcher:Destroy()` |

## 2. Porting Connections
Basic `:Connect()` and `:Once()` are compatible. Note that `Once()` in FuncSignal is optimized via the internal pool.

## 3. Upgrading Execution
Replace your standard `Fire` calls with these for massive gains:
* `Signal:Fire(...)` ➡️ `Dispatcher:FireThreaded(...)`
* **Upgrade:** `Dispatcher:FireNative(...)` (4x faster than spawn)
* **Upgrade:** `Dispatcher:FireHardware(...)` (8.5x faster; raw speed)

## 4. Native Interceptors
Instead of manual wrappers, bake your logic into the dispatcher.
**The FuncSignal way:**
```luau
local Dispatcher = FuncSignal:CreateDispatcher()
Dispatcher:SetCustomIntercept(function(...)
    -- Edit, Parse, or Log arguments globally
    return ...
end)
```

## 5. Cleaning Up Groups (Proxies)
Instead of manual "Janitor" patterns, use `ProxyConnect`.
```luau
local UIProxy = Dispatcher:ProxyConnect({fn1, fn2}, "DEFERRED")
-- Clean up the whole group at once!
UIProxy:Destroy()
```

---
*🎩 "If your game fires signals 1,000 times a frame, **FuncSignal is a requirement.**"*
