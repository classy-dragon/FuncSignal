--!strict
--!native
--[[
    FuncSignal v1.1.5 - Typed,Optimized,ETC
    Copyright ©️ 2026 classy-dragon
    Licensed under the MIT License.
    See LICENSE file in the github respiratory for more license information.
--]]

local FuncSignal = {}

export type DispatcherMacro<T...> = (T...)->()
export type FUNCRuntime = "NATIVE" | "DEFERRED" | "THREADED" | "PCALL" | "DEBUG" | "HARDWARE"
type HeaderFunc = (Macro:any,...any) -> ()
local FUNCRuntimeHeaders:{[FUNCRuntime]:HeaderFunc} = {
	NATIVE = (function(Macro,...) Macro(...) return end),
	DEBUG = (function(Macro,...) print("FuncSignal-Macro-Debug: ",{...}) Macro(...) return end),
	DEFERRED = task.defer :: any,
	THREADED = task.spawn :: any,
	PCALL = pcall :: any,
}

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
		local OFN : (T...) -> ()?
		OFN = function(...)
			FNMacro(...)
			self:RemoveMacro(OFN :: any)
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
		self.ProxyConnection=nil :: any
	end
	self.Disabled=true
	self.__LinkedDispatcherHandleFireIntercept=nil
	self:ClearMacros()
	setmetatable(self,nil)
end

-- Dispatcher Class

-- LIGHT weight (DOD) Connection
export type Connection<T...> = {
	Disconnect:(self:Connection<T...>)->(),
	__Macro:DispatcherMacro<T...>,
	__Dispatcher:Dispatcher<T...>,
}
type PrivateConnection = Connection<...any>
local ConnectionClass = {} :: PrivateConnection & {__index:PrivateConnection}
ConnectionClass.__index = ConnectionClass

function ConnectionClass:Disconnect()
	if self.__Dispatcher then
		local Connections = self.__Dispatcher.__Connections
		local Index = table.find(Connections,self)
		if Index then
			local CLen = #Connections
			Connections[Index] = Connections[CLen]
			Connections[CLen] = nil
		end
	end
	self.__Dispatcher = nil :: any
	self.__Macro = nil :: any
	setmetatable(self,nil)
end

-- (Public) Connections Only --
export type PublicDispatcher<T...> = {
	Connect:(Macro:DispatcherMacro<T...>)->(Connection<T...>),
	BatchConnect:(Macros:{DispatcherMacro<T...>})->({Connection<T...>}),
	ProxyBatchConnect:(Macros:{DispatcherMacro<T...>},Runtime:FUNCRuntime)->(ProxyMacro<T...>),
	Once:(Macro:DispatcherMacro<T...>)->(Connection<T...>),
	Wait:()->(T...),
}

export type Dispatcher<T...> = {
	__Connections:{Connection<T...>},
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
	FirePCALL:(self:Dispatcher<T...>,T...)->(boolean), -- Wraps each listener in an pcall for error safety.
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
		__Connections = {},
		Disabled=false,
		PublicDispatcher = (nil :: any)
	} :: PrivateDispatcher
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

function DispatcherClass:Connect<T...>(Macro:DispatcherMacro<T...>) : Connection<T...>
	local Connection = setmetatable({__Macro=Macro,__Dispatcher=self} :: Connection<T...>,ConnectionClass) :: Connection<T...>
	table.insert(self.__Connections::{Connection<T...>},Connection)
	return Connection
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
	if Method=="HARDWARE" then
		for Index=#self.__Connections,1,-1 do
			local Connection = self.__Connections[Index]
			if Connection then Connection.__Macro(...) end
		end
		return true
	end
	if self.CustomFireARGSIntercept then
		for Index=#self.__Connections,1,-1 do
			local Connection = self.__Connections[Index]
			if Connection then self:HandleFireIntercept(Connection.__Macro,Header,...) end
		end
	else
		for Index=#self.__Connections,1,-1 do
			local Connection = self.__Connections[Index]
			if not Connection then continue end
			Header(Connection.__Macro,...)
		end
	end
	
	return true
end
function DispatcherClass:FireStepped<T...>(StepTime,...:T...)
	if self.Disabled then return false end
	for Index=#self.__Connections,1,-1 do
		local Connection = self.__Connections[Index]
		if Connection then
			Connection.__Macro(...)
			task.wait(StepTime)
		end
	end
	return true
end
function DispatcherClass:Fire<T...>(...:T...) return self:FireThreaded(...) end
function DispatcherClass:FireDebug<T...>(...:T...) return self:MethodFire("DEBUG",...) end
function DispatcherClass:FireNative<T...>(...:T...) return self:MethodFire("NATIVE",...) end
function DispatcherClass:FireDeferred<T...>(...:T...) return self:MethodFire("DEFERRED",...) end
function DispatcherClass:FireThreaded<T...>(...:T...) return self:MethodFire("THREADED",...) end
function DispatcherClass:FirePCALL<T...>(...:T...) return self:MethodFire("PCALL",...) end
function DispatcherClass:FireHardware<T...>(...:T...) return self:MethodFire("HARDWARE",...) end
	
function DispatcherClass:Once<T...>(Macro)
	local Connection : Connection<T...>?
	local function Action(...:T...)
		if Connection then
			Connection:Disconnect()
			Connection=nil :: any
		end
		Macro(...)
	end
	Connection = self:Connect(Action)
	return Connection
end

function DispatcherClass:Wait<T...>()
	local Thread =  coroutine.running()
	self:Once(function(...:T...)
		if coroutine.status(Thread)=="suspended" then
			task.spawn(Thread,...)
		end
	end)
	return coroutine.yield()
end

function DispatcherClass:ClearBindings()
	for _,Connection in self.__Connections do
		Connection:Disconnect()
	end
	table.clear(self.__Connections)
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
