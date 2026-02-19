<p align="center">
  <img src="https://github.com/classy-dragon/FuncSignal/blob/main/FuncSignal.png?raw=true" width="100" alt="FuncSignal Logo">
</p>
<h1 align="center">FuncSignal</h1>
<p align="center">
  <a href="https://luau-lang.org/"><img src="https://img.shields.io/badge/Made%20With%20Luau-6680b4" alt="Made With Luau"></a>
  <a href="[https://luau-lang.org/](https://luau.org/types/object-oriented-programs/)"><img src="https://img.shields.io/badge/Luau - Object%2EOriented%2EProgramming-3f6f97" alt="Made With Luau - OOP"></a>
  <a href="https://github.com/classy-dragon/FuncSignal"><img src="https://img.shields.io/badge/Signal%2FEvent%20Handler-5657be" alt="Signal Handler"></a>
  <img src="https://img.shields.io/badge/Platform-Roblox-white" alt="Platform">
  <img src="https://img.shields.io/badge/Version-1.2.5-blue" alt="Version">
</p>

### **FuncSignal** is a production-grade event system for Luau, benchmarked at over **8x faster** (Gets even Faster then that!) than BindableEvents for primitives and up to **26,000x faster** for complex data for BindableEvents.

---
## ➡️ Quick Links:
* ⚛️ [Why Should I Use FuncSignal?](#whyfs)
* 🔅 [Key Features](#-key-features)
* ⚙️ [Flexible Runtimes](#frt)
* 💽 [Proxy Function Arguments](#pfa)
* 📊 [Performance Benchmarks](#pc)
* ⚠️ [Good Practices](#gp)
* 📦 [Installation](#-installation)
* 🛠 [Usage Examples](#-usage-examples)
* ↗️ [Migration From GoodSignal To FuncSignal](#gsm)
* 📜 [Source Code](https://github.com/classy-dragon/FuncSignal/blob/main/src/FuncSignal.luau)
---

<a name="whyfs"></a>
## ⚛️ Why should *i* use *FuncSignal?*:

Most signal libraries force a trade-off between "simplicity" and "speed." FuncSignal delivers both by utilizing **Data-Oriented Design (DOD)** patterns. By storing connections in contiguous arrays instead of scattered linked lists, we maximize cache locality and keep the Luau VM Fast and Snappy.

### ⛓️‍💥 Break the "C++ Bridge" Bottleneck
Standard Roblox **BindableEvents** are forced to "Deep Copy" data to move it between the Luau VM and the C++ Engine. 
* **The Cost:** This adds massive overhead (300ns - 600ns+) per fire.
* **The FuncSignal Edge:** We stay entirely within the Luau VM, passing memory references via the Stack Pointer. This makes our `HARDWARE` runtime **8.5x faster** than the engine's native solution.

### 🎛️ Data-Oriented Architecture (DOD)
While most libraries use **Linked Lists**, FuncSignal utilizes **Contiguous Arrays**.
* **Why it matters:** Linked lists scatter connections across memory. Arrays keep them in a single block. 
* **The Result:** This provides superior **Cache Locality**, allowing the CPU to prefetch the next listener before the current one even finishes.

### 🔅 Key Features:
* **Zero-Allocation Dispatch:** `v1.1.5`+ update removed `table.clone` from the core dispatch loop. Firing a signal now costs near-zero memory.
* **Flexible Runtimes:** Switch execution strategies on the fly. Full support for `NATIVE`, `DEFERRED`, `THREADED`, and `PCALL`.
* **Middleware Interceptors:** A global "hook" system that allows you to modify, sanitize, or validate data *before* it reaches any listener.
* **Proxy Batches:** Branch a single dispatcher into multiple "Proxy Groups." Perfect for decoupling UI, Audio, and Physics logic without extra event overhead.
* **O(1) Disconnection:** Uses a swap-with-last array pop to ensure disconnecting a listener is instantaneous, regardless of how many listeners you have.
  
---

<a name="frt"></a>
## ⚙️ Flexible Runtimes:
| Runtime | Style | Description | Best For... |
| :--- | :--- | :--- | :--- |
| **`NATIVE`** | **Sync** | Executes immediately on the **same** thread. | Core logic & high-speed math. |
| **`DEFERRED`** | **Async** | Executes at the end of the current engine step. | UI updates & state replication. |
| **`THREADED`** | **Spawn** | Wraps each listener in `task.spawn`. | Independent, heavy processes. |
| **`PCALL`** | **Safe** | Wraps execution in a protected call. | 3rd-party code or unstable plugins. |
| **`HARDWARE`**| **Raw** | Bypasses all headers/interceptors for raw speed. | NATIVE HARDWARE |

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
SignalMonitor.ExampleFS:SetCustomFireARGSIntercept(function(...)
    -- Log the arguments to a table before passing them to listeners
    table.insert(SignalMonitor.Logs, "Fired with: " .. HttpService:JSONEncode({...}))
    return ...
end)
```

---

<a name="pc"></a>
## 📊 Performance Context
FuncSignal's performance advantage scales with data complexity.
* **Primitive Data (Number/String):** Roughly **8x - 10x faster** than BindableEvents.
* **Complex Data (Large Tables):** Up to **26,000x faster**.

**The Reason:** Roblox `BindableEvents` perform a "Deep Copy" of all arguments to cross the **C++/Lua bridge**. FuncSignal remains entirely within the Luau VM, passing references via the Stack Pointer. No bridge, no copy, no lag.

---

<a name="gp"></a>
## ⚠️ Good Practices:
* **Do NOT Yield in Native:** `FireNative` and `FireHardware` are synchronous. To maintain performance, avoid using `task.wait()` in these listeners.
* **Use Proxies for UI:** I recommend the `DEFERRED` runtime for UI updates to ensure they don't block critical game logic frames.
* **Safe Cleanup:** Always use `:Destroy()` or `:ClearBindings()`, After your ready to destroy/stop using it, It ensures the Luau Garbage Collector can reclaim memory immediately.
* **FireHardware:** Use this when every nanosecond counts. It bypasses the Interceptor pipeline and provides the rawest dispatch loop possible.

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
local Dispatcher = FuncSignal:CreateDispatcher() :: FuncSignal.Dispatcher<string>

-- Force all outgoing string data to be uppercase
Dispatcher:SetCustomFireARGSIntercept(function(Input: string)
	return Input:upper()
end)

Dispatcher:Connect(print) -- on fire > print
Dispatcher:FireNative("hello") -- Output: HELLO
```
### 2. OOP, Events/Signals
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
### 3. OOP, Easy Signal Monitoring:
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
	SignalMonitor.MonitoredDispatcher:SetCustomFireARGSIntercept(function(...)
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

If you're moving from **GoodSignal** (Linked List) to **FuncSignal** (DOD Array), the API is designed to be familiar, but the internal "engine" works differently. Follow this guide to swap over without breaking your systems.

---

## 1. The Core Constructor
GoodSignal uses a standard `.new()` pattern. FuncSignal uses a `CreateDispatcher()` pattern to clearly distinguish between the "Source" (Dispatcher) and the "Receivers" (PublicDispatcher).

| Feature | GoodSignal | FuncSignal |
| :--- | :--- | :--- |
| **Constructor** | `local Signal = GoodSignal.new()` | `local Dispatcher = FuncSignal:CreateDispatcher()` |
| **Bulk Disconnect** | `Signal:DisconnectAll()` | `Dispatcher:ClearBindings()` |
| **Cleanup** | `Signal:Destroy()` | `Dispatcher:Destroy()` |

---

## 2. Porting Basic Connections
The basic `:Connect()` and `:Once()` logic remains identical, making the initial swap easy.

**GoodSignal:**
```luau
local Connection = signal:Connect(function(...)
    print("Received:", ...)
end)
```

**FuncSignal:**
```luau
local Connection = Dispatcher:Connect(function(...)
    print("Received:", ...)
end)
```

---

## 3. Upgrading Your Execution Strategy
In GoodSignal, firing logic is fixed. In FuncSignal, you choose your "Gear" based on the task. Use this table to map your old logic to new, faster methods.

| Old Logic | New FuncSignal Method | Reason to Switch |
| :--- | :--- | :--- |
| `Signal:Fire(...)` | `Dispatcher:FireThreaded(...)` | Standard `task.spawn` safety. |
| N/A | `Dispatcher:FireNative(...)` | **Upgrade:** 4x faster; runs on the same thread. |
| N/A | `Dispatcher:FireHardware(...)` | **Upgrade:** 8.5x faster; skips all middleware. |
| `pcall(Signal.Fire, ...)` | `Dispatcher:FirePCALL(...)` | Cleaner syntax for error-prone third-party code. |

---

## 4. Converting Wrappers to Interceptors
If you were manually wrapping signals to format data in GoodSignal, you can now move that logic directly into the dispatcher. This reduces your stack depth and simplifies your code.

**The GoodSignal way (Wrapped):**
---luau
local rawSignal = GoodSignal.new()
local function FireFormatted(data)
    rawSignal:Fire(data:lower()) -- Manual wrapping adds a stack frame
end
---

**The FuncSignal way (Native Interceptor):**
```luau
local Dispatcher = FuncSignal:CreateDispatcher()
Dispatcher:SetCustomFireARGSIntercept(function(data)
    return data:lower() -- Baked into the signal core, no extra trouble.
end)
```
OR
```luau
local Dispatcher = FuncSignal:CreateDispatcher()
Dispatcher:SetCustomFireARGSIntercept(function(...)
	-- You can Edit,Parse,etc The Fire Function arguments, this can be used for printing,Formatting
    return ...
end)
```

---

## 5. Cleaning Up Groups (Proxies)
Instead of manually tracking an array of connections to disconnect them all later, use `ProxyBatchConnect`. This replaces the need for "Maid" or "Janitor" patterns for specific event groups.

## GoodSignal, You have to track these manually
```luau
local conn1 = Signal:Connect(fn1)
local conn2 = Signal:Connect(fn2)
-- Manually disconnect later.
```
## FuncSignal, Group them into a Proxy:
```Luau
local UIProxy = Dispatcher:ProxyBatchConnect({fn1, fn2}, "DEFERRED")
-- Clean up the whole group at once easily!
UIProxy:Destroy()
```

---

## 6. Type Safety Changes
FuncSignal uses Luau’s `export type` system for better Autocomplete and strict type checking.
-- If you used types in GoodSignal:
```luau
local Signal = GoodSignal.new() ::  :: GoodSignal.Signal<number, string>
local EventOnlySignal = EventOnlySignal:GetEventOnlySignal() :: GoodSignal.Signal<number, string>
```
```luau
-- Use these in FuncSignal:
local Dispatcher = FuncSignal:CreateDispatcher() :: FuncSignal.Dispatcher<string> -- Put your Fire/Connect types you want here
local PublicDispatcher = Dispatcher.PublicDispatcher :: FuncSignal.PublicDispatcher<string> -- match the main dispatcher! ^
```

> **Performance Tip:** If you are migrating a high-frequency system (like a Bullet Processor or Character Controller), swap your `Fire` calls to `FireNative` or `FireHardware`. This is where you will see the 8.5x performance leap over standard signals.

---

> "If you are building a simple UI button, any signal library will work. But if you are building an RPG with massive inventories, a simulator with thousands of moving parts, or a global state system, the performance gain of FuncSignal is the difference between a smooth 60 FPS and a lagging game."



> "If your game fires signals 10 times a minute, any library works. If your game fires signals 1,000 times a frame, **FuncSignal is a requirement.**"

---
*🎩*
