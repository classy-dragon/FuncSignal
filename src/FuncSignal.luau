--!strict
--!native
--[[
    FuncSignal v1.1.5
    Copyright ©️ 2026 classy-dragon
    Licensed under the MIT License.
    See LICENSE file in the github respiratory for more license information.
--]]

local FuncSignal = {}

export type DispatcherMacro=(...any)->()
export type FUNCRuntime = "NATIVE" | "DEFERRED" | "THREADED" | "PCALL" | "DEBUG"
local FUNCRuntimeHeaders:{[FUNCRuntime]:(Macro:DispatcherMacro | any,...any)->any} = {
	NATIVE = (function(Macro,...) Macro(...) return end),
	DEBUG = (function(Macro,...) print("FuncSignal-Macro-Debug: ",{...}) Macro(...) return end),
	DEFERRED = task.defer,
	THREADED = task.spawn,
	PCALL = pcall,
}

-- Connection Class

export type Connection = {
	__DataLinker:{[DispatcherMacro]:Connection},
	__Macro:DispatcherMacro,
	Disconnect:(self:Connection)->()
}

local ConnectionClass = {} :: Connection & {__index:Connection}
ConnectionClass.__index=ConnectionClass

function FuncSignal:CreateConnection(Macro:DispatcherMacro,Datalinker:{[DispatcherMacro]:Connection})
	local NewConnection = {
		__DataLinker=Datalinker,
		__Macro=Macro
	}  :: Connection
	setmetatable(NewConnection,ConnectionClass)
	Datalinker[Macro]=NewConnection
	return NewConnection
end

function ConnectionClass:Disconnect()
	if self.__DataLinker[self.__Macro] then
		self.__DataLinker[self.__Macro]=nil
	end
	setmetatable(self,nil)
end


-- Proxy Macro

export type ProxyMacro={
	Macros:{[DispatcherMacro]:boolean},
	Disabled:boolean,
	Payload:any,
	ProxyConnection:Connection,
	Runtime:FUNCRuntime,
	SetRuntime:(self:ProxyMacro,NewRuntime:FUNCRuntime)->(),
	Fire:(self:ProxyMacro,...any | any)->(boolean),
	PushMacro:(self:ProxyMacro,DispatcherMacro | {DispatcherMacro})->(),
	PushONCEMacro:(self:ProxyMacro,DispatcherMacro | {DispatcherMacro})->(),
	RemoveMacro:(self:ProxyMacro,DispatcherMacro)->(boolean),
	ClearMacros:(self:ProxyMacro)->(),
	Destroy:(self:ProxyMacro)->(),
	__LinkedDispatcherHandleFireIntercept : (Macro:DispatcherMacro | any,Header:(DispatcherMacro | any,...any)->(),...any) -> ()?
}

local ProxyMacroClass = {} :: ProxyMacro & {__index:ProxyMacro}
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

function ProxyMacroClass:PushONCEMacro(Macro)
	local function OnceMacroWrapper(FNMacro)
		local OFN : (...any) -> ()
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
export type PublicDispatcher = {
	Connect:(self:Dispatcher,Macro:DispatcherMacro)->(Connection),
	BatchConnect:(self:Dispatcher,Macros:{DispatcherMacro})->({Connection}),
	ProxyBatchConnect:(self:Dispatcher,Macros:{DispatcherMacro},Runtime:FUNCRuntime)->(ProxyMacro),
	Once:(self:Dispatcher,Macro:DispatcherMacro)->(Connection),
	Wait:(self:Dispatcher)->(...any),
}

export type Dispatcher = {
	__FunctionBindings:{[DispatcherMacro]:Connection},
	__ProcessARGS:(self:Dispatcher,...any)->(...any),
	Disabled:boolean, -- Stops (ANY) Fire from sending any signal.
	PublicDispatcher:PublicDispatcher, -- For Public Connections Only (For Unsafe/Locked Events)
	-- Fire Methods
	CustomFireARGSIntercept:(...any)->(...any)?, -- This Intercept Any (Fire) Method ARGS with an custom function (This SHOULD never yield and SHOULD return the input and to output!)
	HandleFireIntercept:(self:Dispatcher,Macro:DispatcherMacro,Header:(DispatcherMacro | any,...any)->(),...any) -> (),
	SetCustomFireARGSIntercept:(self:Dispatcher,Interceptor:(...any)->(...any)) -> (),
	MethodFire:(self:Dispatcher,Runtime:FUNCRuntime,...any)->(boolean),
	Fire:(self:Dispatcher,...any)->(boolean), -- defaults to threaded 
	FireDebug:(self:Dispatcher,...any)->(boolean), -- (Native) Outputs ALL Fire data via print for debugging only.
	FireHardware:(self:Dispatcher,...any)->(boolean), -- Unsafe, Native, No Header, No Intercept.
	FireNative:(self:Dispatcher,...any)->(boolean), -- Executes immediately on the same thread.
	FireDeferred:(self:Dispatcher,...any)->(boolean), -- Executes at the end of the current engine step.
	FireThreaded:(self:Dispatcher,...any)->(boolean), -- Wraps each listener in task.spawn.
	FireStepped:(self:Dispatcher,TimeStep:number,...any)->(boolean), -- (FireHardware) but stepped per second
	-- Connections Methods
	Connect:(self:Dispatcher,Macro:DispatcherMacro)->(Connection),
	BatchConnect:(self:Dispatcher,Macros:{DispatcherMacro})->({Connection}),
	ProxyBatchConnect:(self:Dispatcher,Macros:{DispatcherMacro},Runtime:FUNCRuntime)->(ProxyMacro),
	Once:(self:Dispatcher,Macro:DispatcherMacro)->(Connection),
	Wait:(self:Dispatcher)->(...any),
	-- Clean up Methods
	ClearBindings:(self:Dispatcher)->(),
	Destroy:(self:Dispatcher)->()
}

local DispatcherClass = {} :: Dispatcher & {__index:Dispatcher}
DispatcherClass.__index=DispatcherClass

function FuncSignal:CreateDispatcher()
	local NewDispatcher = {
		__FunctionBindings  = {},
		Disabled=false
	} :: Dispatcher
	setmetatable(NewDispatcher,DispatcherClass)
	-- Public Init --
	NewDispatcher.PublicDispatcher = {
		Connect=NewDispatcher.Connect,
		BatchConnect=NewDispatcher.BatchConnect,
		ProxyBatchConnect=NewDispatcher.ProxyBatchConnect,
		Once=NewDispatcher.Once,
		Wait=NewDispatcher.Wait
	}
	return NewDispatcher
end

function DispatcherClass:Connect(Macro)
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

function DispatcherClass:ProxyBatchConnect(DefaultMacros,Runtime)
	local NewProxyMacro = {
		Macros={},
		Disabled=false,
		Runtime=(Runtime or "THREADED"),
		__LinkedDispatcherHandleFireIntercept = (function(Macro,Header,...:any) self:HandleFireIntercept(Macro,Header,...) end)
	} :: ProxyMacro
	setmetatable(NewProxyMacro,ProxyMacroClass)
	NewProxyMacro.ProxyConnection=self:Connect(function(...)
		NewProxyMacro:Fire(...)
	end)
	if DefaultMacros then
		NewProxyMacro:PushMacro(DefaultMacros)
	end
	return NewProxyMacro
end

function DispatcherClass:__ProcessARGS(...)
	local ARGS = if self.CustomFireARGSIntercept then self.CustomFireARGSIntercept(...) else {...}
	return ARGS
end

function DispatcherClass:HandleFireIntercept(Macro,Header,...)
	if self.CustomFireARGSIntercept then
		Header(Macro,self.CustomFireARGSIntercept(...))
	else
		Header(Macro,...)
	end
end

function DispatcherClass:MethodFire(Method,...)
	if self.Disabled then return false end
	local Header = FUNCRuntimeHeaders[Method]
	local Snapshot = table.clone(self.__FunctionBindings)
	local FNB = self.__FunctionBindings
	for Macro in Snapshot do
		if FNB[Macro] then
			self:HandleFireIntercept(Macro,Header,...)
		end
	end
	table.clear(Snapshot)
	return true
end

function DispatcherClass:Fire(...)
	return self:FireThreaded(...)
end

function DispatcherClass:FireDebug(...)
	return self:MethodFire("DEBUG",...)
end

function DispatcherClass:FireHardware(...)
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

function DispatcherClass:FireNative(...)
	return self:MethodFire("NATIVE",...)
end

function DispatcherClass:FireDeferred(...)
	return self:MethodFire("DEFERRED",...)
end

function DispatcherClass:FireThreaded(...)
	return self:MethodFire("THREADED",...)
end

function DispatcherClass:FireStepped(StepTime,...)
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

function DispatcherClass:Once(Macro)
	local MacroConnection : Connection?
	local function Action(...:any)
		if MacroConnection then
			MacroConnection:Disconnect()
			MacroConnection=nil
		end
		Macro(...)
	end
	MacroConnection = self:Connect(Action)
	return MacroConnection
end

function DispatcherClass:Wait()
	local Thread =  coroutine.running()
	self:Once(function(...)
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
