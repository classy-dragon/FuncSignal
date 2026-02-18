--!strict
--!native
--[[
    FuncSignal v1.1.5
    Copyright ©️ 2026 classy-dragon
    Licensed under the MIT License.
    See LICENSE file in the github respiratory for more license information.
--]]

local FuncSignal = {}

export type DispatcherMacro<T...> = (T...)->()
export type FUNCRuntime = "NATIVE" | "DEFERRED" | "THREADED" | "PCALL" | "DEBUG"
type HeaderFunc = (Macro:any,...any) -> any
local FUNCRuntimeHeaders:{[FUNCRuntime]:HeaderFunc} = {
	NATIVE = (function(Macro,...) Macro(...) return end),
	DEBUG = (function(Macro,...) print("FuncSignal-Macro-Debug: ",{...}) Macro(...) return end),
	DEFERRED = task.defer,
	THREADED = task.spawn,
	PCALL = pcall,
}

-- Connection Class

export type Connection<T...> = {
	__DataLinker:{[DispatcherMacro<T...>]:Connection<T...>},
	__Macro:DispatcherMacro<T...>,
	Disconnect:(self:Connection<T...>)->()
}

type PrivateConnection = Connection<...any>
local ConnectionClass = {} :: PrivateConnection & {__index:PrivateConnection}
ConnectionClass.__index=ConnectionClass

function FuncSignal:CreateConnection<T...>(Macro:DispatcherMacro<T...>,Datalinker:{[DispatcherMacro<T...>]:Connection<T...>})
	local NewConnection = {
		__DataLinker=Datalinker,
		__Macro=Macro
	}  :: PrivateConnection
	setmetatable(NewConnection,ConnectionClass)
	Datalinker[Macro]=(NewConnection :: any)
	return NewConnection
end

function ConnectionClass:Disconnect()
	if self.__DataLinker[self.__Macro] then
		self.__DataLinker[self.__Macro]=nil
	end
	setmetatable(self,nil)
end


-- Proxy Macro

export type ProxyMacro<T...> ={
	Macros:{[DispatcherMacro<T...>]:boolean},
	Disabled:boolean,
	ProxyConnection:Connection<T...>,
	Runtime:FUNCRuntime,
	SetRuntime:(self:ProxyMacro<T...>,NewRuntime:FUNCRuntime)->(),
	Fire:(self:ProxyMacro<T...>,T...)->(boolean),
	PushMacro:(self:ProxyMacro<T...>, DispatcherMacro<T...> | {DispatcherMacro<T...>})->(),
	PushONCEMacro:(self:ProxyMacro<T...>,DispatcherMacro<T...> | {DispatcherMacro<T...>})->(),
	RemoveMacro:(self:ProxyMacro<T...>,DispatcherMacro<T...>)->(boolean),
	ClearMacros:(self:ProxyMacro<T...>)->(),
	Destroy:(self:ProxyMacro<T...>)->(),
	__LinkedDispatcherHandleFireIntercept : (Macro:DispatcherMacro<T...>,Header:(DispatcherMacro<T...>,T...)->(),T...) -> ()?
}

type PrivateProxyMacro = ProxyMacro<...any>
local ProxyMacroClass = {} :: PrivateProxyMacro & {__index:PrivateProxyMacro}
ProxyMacroClass.__index=ProxyMacroClass

function ProxyMacroClass:Fire(...)
	if not self.__LinkedDispatcherHandleFireIntercept or self.Disabled then return false end
	local Header = FUNCRuntimeHeaders[self.Runtime]
	for Macro in self.Macros do
		self.__LinkedDispatcherHandleFireIntercept(Macro,Header,...)
	end
	return true
end

function ProxyMacroClass:PushMacro(Macro)
	if typeof(Macro) == "table" then
		for _,FNMacro in Macro do
			self.Macros[FNMacro]=true
		end
	else
		self.Macros[Macro]=true
	end
end

function ProxyMacroClass:PushONCEMacro<T...>(Macro)
	local function OnceMacroWrapper(FNMacro)
		local OFN : (T...) -> ()
		OFN = function(...)
			self:RemoveMacro(OFN)
			FNMacro(...)
		end
		self.Macros[OFN]=true
	end
	if typeof(Macro) == "table" then
		for _,FNMacro in Macro do
			OnceMacroWrapper(FNMacro)
		end
	else
		OnceMacroWrapper(Macro)
	end
end

function ProxyMacroClass:RemoveMacro(Macro)
	if self.Macros[Macro] then
		self.Macros[Macro]=nil
		return true
	end
	return false
end

function ProxyMacroClass:ClearMacros()
	table.clear(self.Macros)
end

function ProxyMacroClass:SetRuntime(Runtime)
	self.Runtime=Runtime
end

function ProxyMacroClass:Destroy()
	if self.ProxyConnection then
		self.ProxyConnection:Disconnect()
	end
	self.Disabled=true
	self.__LinkedDispatcherHandleFireIntercept=nil
	self:ClearMacros()
	setmetatable(self,nil)
end

-- Dispatcher Class

-- (Public) Connections Only --
export type PublicDispatcher<T...> = {
	Connect:(Macro:DispatcherMacro<T...>)->(Connection<T...>),
	BatchConnect:(Macros:{DispatcherMacro<T...>})->({Connection<T...>}),
	ProxyBatchConnect:(Macros:{DispatcherMacro<T...>},Runtime:FUNCRuntime)->(ProxyMacro<T...>),
	Once:(Macro:DispatcherMacro<T...>)->(Connection<T...>),
	Wait:()->(T...),
}

export type Dispatcher<T...> = {
	__FunctionBindings:{[DispatcherMacro<T...>]:Connection<T...>},
	Disabled:boolean, -- Stops (ANY) Fire from sending any signal.
	PublicDispatcher:PublicDispatcher<T...>, -- For Public Connections Only (For Unsafe/Locked Events)
	-- Fire Methods
	CustomFireARGSIntercept:(T...)->(T...)?, -- This Intercept Any (Fire) Method ARGS with an custom function (This SHOULD never yield and SHOULD return the input and to output!)
	HandleFireIntercept:(self:Dispatcher<T...>,Macro:DispatcherMacro<T...>,Header:(DispatcherMacro<T...>)->(),T...) -> (),
	SetCustomFireARGSIntercept:(self:Dispatcher<T...>,Interceptor:(T...)->(T...)) -> (),
	MethodFire:(self:Dispatcher<T...>,Runtime:FUNCRuntime,T...)->(boolean),
	-- Main Fire Methods
	Fire:(self:Dispatcher<T...>,T...)->(boolean), -- defaults to threaded 
	FireDebug:(self:Dispatcher<T...>,T...)->(boolean), -- (Native) Outputs ALL Fire data via print for debugging only.
	FireHardware:(self:Dispatcher<T...>,T...)->(boolean), -- Unsafe, Native, No Header, No Intercept.
	FireNative:(self:Dispatcher<T...>,T...)->(boolean), -- Executes immediately on the same thread.
	FireDeferred:(self:Dispatcher<T...>,T...)->(boolean), -- Executes at the end of the current engine step.
	FireThreaded:(self:Dispatcher<T...>,T...)->(boolean), -- Wraps each listener in task.spawn.
	FireStepped:(self:Dispatcher<T...>,TimeStep:number,T...)->(boolean), -- (FireHardware) but stepped per second
	-- Connections Methods
	Connect:(self:Dispatcher<T...>,Macro:DispatcherMacro<T...>)->(Connection<T...>),
	BatchConnect:(self:Dispatcher<T...>,Macros:{DispatcherMacro<T...>})->({Connection<T...>}),
	ProxyBatchConnect:(self:Dispatcher<T...>,Macros:{DispatcherMacro<T...>},Runtime:FUNCRuntime)->(ProxyMacro<T...>),
	Once:(self:Dispatcher<T...>,Macro:DispatcherMacro<T...>)->(Connection<T...>),
	Wait:(self:Dispatcher<T...>)->(T...),
	-- Clean up Methods
	ClearBindings:(self:Dispatcher<T...>)->(),
	Destroy:(self:Dispatcher<T...>)->()
}

type PrivateDispatcher = Dispatcher<...any>
local DispatcherClass = {} :: PrivateDispatcher & {__index:PrivateDispatcher}
DispatcherClass.__index=DispatcherClass

function FuncSignal:CreateDispatcher<T...>(): Dispatcher<T...>
	local NewDispatcher = {
		__FunctionBindings = {},
		Disabled=false,
		PublicDispatcher = (nil :: any)
	}
	setmetatable(NewDispatcher,DispatcherClass)
	-- Public Init --
	local TDispatcher = NewDispatcher :: Dispatcher<T...>
	TDispatcher.PublicDispatcher = {
		Connect=function(Macro) return TDispatcher:Connect(Macro) end,
		BatchConnect=function(Macros) return TDispatcher:BatchConnect(Macros) end,
		ProxyBatchConnect=function(Default,Runtime) return TDispatcher:ProxyBatchConnect(Default,Runtime) end,
		Once=function(Macro) return TDispatcher:Once(Macro) end,
		Wait=function() return TDispatcher:Wait() end
	}
	return NewDispatcher :: Dispatcher<T...>
end

function DispatcherClass:Connect<T...>(Macro:DispatcherMacro<T...>)
	local NewConnection = FuncSignal:CreateConnection(Macro,self.__FunctionBindings)
	return NewConnection
end

function DispatcherClass:BatchConnect(Macros)
	local Connections = {}
	for _,Macro in Macros do
		table.insert(Connections,self:Connect(Macro))
	end
	return Connections
end

function DispatcherClass:ProxyBatchConnect<T...>(DefaultMacros,Runtime)
	local NewProxyMacro = {
		Macros={},
		Disabled=false,
		Runtime=(Runtime or "THREADED"),
		__LinkedDispatcherHandleFireIntercept = (function(Macro,Header,...:T...) self:HandleFireIntercept(Macro,Header,...) end)
	} :: PrivateProxyMacro
	setmetatable(NewProxyMacro,ProxyMacroClass)
	NewProxyMacro.ProxyConnection=self:Connect(function(...)
		NewProxyMacro:Fire(...)
	end)
	if DefaultMacros then
		NewProxyMacro:PushMacro(DefaultMacros)
	end
	return NewProxyMacro
end

function DispatcherClass:HandleFireIntercept(Macro,Header,...)
	if self.CustomFireARGSIntercept then
		Header(Macro,self.CustomFireARGSIntercept(...))
	else
		Header(Macro,...)
	end
end

function DispatcherClass:MethodFire<T...>(Method,...: T...)
	if self.Disabled then return false end
	local Header = FUNCRuntimeHeaders[Method]
	local FNB = self.__FunctionBindings
	for Macro in table.clone(self.__FunctionBindings) do
		if FNB[Macro] then
			self:HandleFireIntercept(Macro,Header,...)
		end
	end
	return true
end
function DispatcherClass:FireHardware<T...>(...:T...)
	if self.Disabled then return false end
	local Snapshot = table.clone(self.__FunctionBindings)
	local FNB = self.__FunctionBindings
	for Macro in Snapshot do
		if FNB[Macro] then
			Macro(...)
		end
	end
	table.clear(Snapshot)
	return true
end
function DispatcherClass:FireStepped<T...>(StepTime,...:T...)
	if self.Disabled then return false end
	local Snapshot = table.clone(self.__FunctionBindings)
	local FNB = self.__FunctionBindings
	for Macro in Snapshot do
		if FNB[Macro] then
			Macro(...)
			task.wait(StepTime)
		end
	end
	table.clear(Snapshot)
	return true
end
function DispatcherClass:Fire<T...>(...:T...) return self:FireThreaded(...) end
function DispatcherClass:FireDebug<T...>(...:T...) return self:MethodFire("DEBUG",...) end
function DispatcherClass:FireNative<T...>(...:T...) return self:MethodFire("NATIVE",...) end
function DispatcherClass:FireDeferred<T...>(...:T...) return self:MethodFire("DEFERRED",...) end
function DispatcherClass:FireThreaded<T...>(...:T...) return self:MethodFire("THREADED",...) end

function DispatcherClass:Once<T...>(Macro)
	local MacroConnection : PrivateConnection?
	local function Action(...:T...)
		if MacroConnection then
			MacroConnection:Disconnect()
			MacroConnection=nil
		end
		Macro(...)
	end
	MacroConnection = self:Connect(Action)
	return MacroConnection
end

function DispatcherClass:Wait<T...>()
	local Thread =  coroutine.running()
	self:Once(function(...:T...)
		task.spawn(Thread,...)
	end)
	return coroutine.yield()
end

function DispatcherClass:ClearBindings()
	for _, MacroConnection in self.__FunctionBindings do
		MacroConnection:Disconnect()
	end
	table.clear(self.__FunctionBindings)
end

function DispatcherClass:SetCustomFireARGSIntercept(Interceptor)
	self.CustomFireARGSIntercept=Interceptor
end

function DispatcherClass:Destroy()
	self.Disabled=true
	self:ClearBindings()
	setmetatable(self,nil)
end

return FuncSignal
