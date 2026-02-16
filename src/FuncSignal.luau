--!strict
--!native
local FuncSignal = {}

export type FUNCRuntime = "NATIVE" | "DEFERRED" | "THREADED" | "PCALL" | "STEPPED"

local RuntimeHeader = function(Method:FUNCRuntime,StepTIME:number?)
	return if Method=="NATIVE" then (function(Macro,...) Macro(...) end)
		elseif Method=="DEFERRED" then task.defer
		elseif Method=="THREADED" then task.spawn
		elseif Method=="STEPPED" then (function(Macro,...) Macro(...) task.wait(StepTIME) end)
		else pcall	
end

export type DispatcherMacro=(...any)->()
export type ProxyMacro={
	Macros:{[DispatcherMacro]:boolean},
	Payload:any,
	ProxyConnection:Connection,
	Runtime:FUNCRuntime,
	SetRuntime:(self:ProxyMacro,NewRuntime:FUNCRuntime)->(),
	Fire:(self:ProxyMacro,Payload:any?)->(),
	PushMacro:(self:ProxyMacro,DispatcherMacro | {DispatcherMacro})->(),
	PushONCEMacro:(self:ProxyMacro,DispatcherMacro | {DispatcherMacro})->(),
	RemoveMacro:(self:ProxyMacro,DispatcherMacro)->(boolean),
	ClearMacros:(self:ProxyMacro)->(),
	Destroy:(self:ProxyMacro)->()
}
export type Dispatcher = {
	__FunctionBindings:{[DispatcherMacro]:Connection},
	Disabled:boolean,
	CustomFireARGSIntercept:(...any)->(...any)?, -- This Intercept Any (Fire) Method ARGS with an custom function (This SHOULD never yield and SHOULD return the input and to output!)
	MethodFire:(self:Dispatcher,Runtime:FUNCRuntime,N:number,...any)->(),
	Fire:(self:Dispatcher,...any)->(), -- defaults to threaded 
	FireHardware:(self:Dispatcher,...any)->(), -- Unsafe, Native, No Header, No Intercept.
	FireNative:(self:Dispatcher,...any)->(),
	FireDeferred:(self:Dispatcher,...any)->(),
	FireThreaded:(self:Dispatcher,...any)->(),
	__ProcessARGS:(self:Dispatcher,...any)->(...any),
	SetCustomFireARGSIntercept:(self:Dispatcher,Interceptor:(...any)->(...any)) -> (),
	FireStepped:(self:Dispatcher,TimeStep:number,...any)->(),
	Connect:(self:Dispatcher,Macro:DispatcherMacro)->(Connection),
	BatchConnect:(self:Dispatcher,Macros:{DispatcherMacro})->({Connection}),
	ProxyBatchConnect:(self:Dispatcher,Macros:{DispatcherMacro})->(ProxyMacro),
	Once:(self:Dispatcher,Macro:DispatcherMacro)->(Connection),
	Wait:(self:Dispatcher)->(...any),
	ClearBindings:(self:Dispatcher)->(),
	Destroy:(self:Dispatcher)->()
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

-- Dispatcher Class

local DispatcherClass = {} :: Dispatcher & {__index:Dispatcher}
DispatcherClass.__index=DispatcherClass
local ProxyMacroClass = {} :: ProxyMacro & {__index:ProxyMacro}
ProxyMacroClass.__index=ProxyMacroClass

function FuncSignal:CreateDispatcher()
	local NewDispatcher = {
		__FunctionBindings  = {},
		Disabled=false
	} :: Dispatcher
	setmetatable(NewDispatcher,DispatcherClass)
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

-- Proxy Macro

function DispatcherClass:ProxyBatchConnect(DefaultMacros,Runtime:FUNCRuntime?)
	local NewProxyMacro = {
		Macros={},
		Runtime=(Runtime or "THREADED")
	} :: ProxyMacro
	setmetatable(NewProxyMacro,ProxyMacroClass)
	NewProxyMacro.ProxyConnection=self:Connect(function()
		NewProxyMacro:Fire()
	end)
	if DefaultMacros then
		NewProxyMacro:PushMacro(DefaultMacros)
	end
	return NewProxyMacro
end

function ProxyMacroClass:Fire(...)
	local Payload = {...}
	if #Payload<1 then
		Payload=(self.Payload or {})
	end
	local Header = RuntimeHeader(self.Runtime)
	for Macro in self.Macros do
		Header(Macro,table.unpack(Payload,1,table.maxn(Payload)))
	end
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
	self:ClearMacros()
	setmetatable(self,nil)
end

-- Dispatcher

function DispatcherClass:__ProcessARGS(...)
	local ARGS = if self.CustomFireARGSIntercept then self.CustomFireARGSIntercept(...) else {...}
	return ARGS
end

function DispatcherClass:MethodFire(Method,N:number,...)
	if self.Disabled then return end
	local Header = RuntimeHeader(Method,N)
	local Snapshot = table.clone(self.__FunctionBindings)
	local ARGS = self:__ProcessARGS(...)
	local ARGSC = table.maxn(ARGS)
	for Macro in Snapshot do
		if self.__FunctionBindings[Macro] then
			Header(Macro,table.unpack(ARGS,1,ARGSC))
		end
	end
	table.clear(Snapshot)
end

function DispatcherClass:Fire(...)
	self:FireThreaded(...)
end

function DispatcherClass:FireHardware(...)
	if self.Disabled then return end
	local Snapshot = table.clone(self.__FunctionBindings)
	for Macro in Snapshot do
		if self.__FunctionBindings[Macro] then
			Macro(...)
		end
	end
	table.clear(Snapshot)
end

function DispatcherClass:FireNative(...)
	self:MethodFire("NATIVE",0,...)
end

function DispatcherClass:FireDeferred(...)
	self:MethodFire("DEFERRED",0,...)
end

function DispatcherClass:FireThreaded(...)
	self:MethodFire("THREADED",0,...)
end

function DispatcherClass:FireStepped(StepTime,...)
	self:MethodFire("STEPPED",(StepTime or 0),...)
end

function DispatcherClass:Once(Macro)
	local MacroConnection : Connection
	local function Action(...:any)
		if MacroConnection then
			MacroConnection:Disconnect()
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
	self:ClearBindings()
	setmetatable(self,nil)
end

return FuncSignal
