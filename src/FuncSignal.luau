--!strict
--!native
--[[
    FuncSignal v2.0.0
    Copyright ©️ 2026 classy-dragon
    Licensed under the MIT License.
    See LICENSE file in the github repository for more license information.
--]]

local FuncSignal = {}

export type DispatcherMacro<T...> = (T...) -> ...any
export type Runtime = "NATIVE" | "DEFERRED" | "THREADED" | "PCALL" | "DEBUG" | "STEPPED" | "HARDWARE" | "PARALLEL"
type HeaderFunc = (Macro:any,...any) -> any
local RuntimeHeaders:{[Runtime]:HeaderFunc}

-- Global Functions
function __HARDWARE<T...>(C:(T...)->(...any),...:T...)
	return C(...)
end
function __DispatcherRawFire<T...>(CL:number,C:{Connection<T...>},Header:(DispatcherMacro<T...>,T...)->(any)?,...:T...)
	if not Header then Header=__HARDWARE end
	for Index=CL,1,-1 do
		local C = C[Index]
		if C and C.__Macro then
			Header(C.__Macro,...)
		end
	end
end

-- Roblox Global Overhead
local TS = task.spawn
local TD = task.defer
local TW = task.wait
local PC = pcall
local CR = coroutine.running
local CY = coroutine.yield
local TDS = task.desynchronize
local TSY = task.synchronize
local RS = game:GetService("RunService")

RuntimeHeaders = {
	NATIVE = (function(Macro,...) return Macro(...) end),
	STEPPED = (function(Macro,StepTime:number,...) TW(StepTime or 1) return RuntimeHeaders.NATIVE(Macro,...)  end),
	DEBUG = (function(Macro,...) print("Funcsignal Dispatcher DEBUG:\n",...) return RuntimeHeaders.NATIVE(Macro,...) end),
	PARALLEL = (function(Macro,Resync:boolean?,...) TDS() local Status,Result = PC(Macro,...) if Resync==true then TSY() end if not Status then warn("FuncSignal: Error in Parallel runtime header: ", Result) end return Result end),
	DEFERRED = TD :: any,
	THREADED = TS :: any,
	PCALL = PC :: any,
}

-- (Light-weight) Connection Class

export type Connection<T...> = {
	Disconnect:(self:Connection<T...>)->(),
	RebindMacro:(self:Connection<T...>,NewMacro:DispatcherMacro<T...>)->(),
	__Pooling:boolean,
	__Macro:DispatcherMacro<T...>,
	__CleanMethod:()->(),
}
type PrivateConnection = Connection<...any>
local ConnectionsPool:{Connection<...any>} = {}
local ConnectionClass = {} :: PrivateConnection & {__index:PrivateConnection}

function __CreateConnection<T...>(Macro:DispatcherMacro<T...>,CleanUpMethod:()->(),UsePooling:boolean?) : Connection<T...>
	local NewConnection = {
		__Macro=Macro,
		__CleanMethod=CleanUpMethod,
		__Pooling=(if UsePooling==nil then true else UsePooling :: boolean)
	} :: Connection<T...>
	setmetatable(NewConnection,{
		__index = ConnectionClass,
	})
	return NewConnection :: Connection<T...>
end

-- (Light-weight) Fire Filter

export type FFLayerMacro<T...> = (T...) -> (boolean) -- Must return an bool if [Your function state] passed.
export type FireFilter<T...> = {
	Layers : {FFLayerMacro<T...>},
	Import: (self:FireFilter<T...>,FFLayerMacro<T...>)->({Disconnect:()->(boolean),Connected:boolean}),
	Run: (self:FireFilter<T...>,T...) -> (boolean), -- Returned Passed Status
	DisconnectLayers: (self:FireFilter<T...>)->(),
	Destroy: (self:FireFilter<T...>)->()
}
local FireFilterClass = {} :: FireFilter<...any>

function __CreateFireFilter<T...>() : FireFilter<T...>
	local FireFilter = {
		Layers={}
	} :: FireFilter<T...>
	setmetatable(FireFilter,{__index=FireFilterClass})
	return FireFilter
end

function FireFilterClass:Run<T...>(...:T...)
	local Layers = self.Layers
	local LayersLen = #Layers
	if LayersLen<1 then return true end
	for Index=LayersLen,1,-1 do
		local LayerMacro = self.Layers[Index]
		if not LayerMacro then continue end
		if LayerMacro(...)==false then
			return false
		end
	end
	return true
end

function FireFilterClass:DisconnectLayers()
	table.clear(self.Layers)
end

function FireFilterClass:Import(LayerMacro)
	local Connected = true
	table.insert(self.Layers,LayerMacro)
	return {
		Disconnect=function()
			if not Connected then return false end
			local Layers = self.Layers
			local LayersLen = #Layers
			local Index = table.find(self.Layers,LayerMacro)
			if Index then
				self.Layers[Index] = Layers[LayersLen]
				Layers[LayersLen]=nil
				Connected=false
			end
			return true
		end,
		Connected=Connected
	}
end

function FireFilterClass:Destroy()
	self:DisconnectLayers()
	setmetatable(self,nil)
end

function __CreateConnectionFromPool<T...>(Macro:DispatcherMacro<T...>,CleanUpMethod:()->(),UsePooling:boolean?) : Connection<T...>
	local UsePooling = if UsePooling==nil then true else UsePooling :: boolean
	local NewConnection = table.remove(ConnectionsPool) :: Connection<T...>
	if NewConnection then
		NewConnection.__Macro=Macro
		NewConnection.__CleanMethod=CleanUpMethod
		NewConnection.__Pooling = UsePooling
		return NewConnection		
	else
		return __CreateConnection(Macro,CleanUpMethod,UsePooling)
	end
end

function ConnectionClass:Disconnect()
	local Cleanup = self.__CleanMethod
	if not self.__CleanMethod then return end
	Cleanup()
	self.__CleanMethod = nil :: any
	self.__Macro = nil :: any
	if self.__Pooling then
		table.insert(ConnectionsPool,self)
	else
		setmetatable(self,nil)
	end
end

function ConnectionClass:RebindMacro(NewMacro)
	self.__Macro=NewMacro
end

-- Proxy Macro

export type ProxyMacro<T...> ={
	Connections:{Connection<T...>},
	Disabled:boolean,
	CurrentRuntime:Runtime,
	FireFilter:FireFilter<T...>,
	-- Methods
	SetRuntime:(self:ProxyMacro<T...>,NewRuntime:Runtime)->(),
	Fire:(self:ProxyMacro<T...>,T...)->(boolean),
	MethodFire:(self:ProxyMacro<T...>,Method:Runtime,T...)->(boolean),
	Connect:(self:ProxyMacro<T...>,Macro:DispatcherMacro<T...>,UsePooling:boolean?)->(Connection<T...>),
	ConnectOnce:(self:ProxyMacro<T...>,Macro:DispatcherMacro<T...>)->(Connection<T...>),
	BulkConnect:(self:ProxyMacro<T...>,{DispatcherMacro<T...>}) -> ({Connection<T...>}),
	DisconnectAll:(self:ProxyMacro<T...>)->(),
	Destroy:(self:ProxyMacro<T...>)->(),
	-- Private
	__MainProxyConnection:Connection<T...>,
	__ParseARGS : (T...) -> T...
}

type PrivateProxyMacro = ProxyMacro<...any>
local ProxyMacroClass = {} :: PrivateProxyMacro & {__index:PrivateProxyMacro}

function ProxyMacroClass:SetRuntime(Runtime)
	self.CurrentRuntime=Runtime
end

function ProxyMacroClass:Fire<T...>(...:T...)
	return self:MethodFire(self.CurrentRuntime,...)
end

function ProxyMacroClass:MethodFire<T...>(Method,...:T...)
	local Connections = self.Connections
	local ConnectionsLen = #Connections
	if self.Disabled or ConnectionsLen<1 or (not FireFilterClass:Run(...)) then return false end
	if Method=="HARDWARE" then
		__DispatcherRawFire(ConnectionsLen,Connections,nil::any,...)
	else
		local Header = RuntimeHeaders[Method]
		if not Header then warn(`Failed Match "{Method} with Runtime Headers."`) return false end
		__DispatcherRawFire(ConnectionsLen,Connections,Header,self.__ParseARGS(...))
	end
	return true
end

function ProxyMacroClass:Connect<T...>(Macro,UsePooling)
	local NewConnection : Connection<T...>
	NewConnection = __CreateConnectionFromPool(Macro,function()
		local Connections = self.Connections :: {Connection<T...>}
		local Index = table.find(Connections,NewConnection::Connection<T...>)
		if Index then
			local CLen = #Connections
			Connections[Index] = Connections[CLen]
			Connections[CLen] = nil
		end
	end,UsePooling)
	table.insert(self.Connections,NewConnection)
	return NewConnection
end

function ProxyMacroClass:BulkConnect<T...>(MacroImport)
	local Result = {}
	for _,Macro in MacroImport do
		local Connection = self:Connect(Macro)
		table.insert(Result,Connection)
	end
	return Result
end

function ProxyMacroClass:ConnectOnce<T...>(Macro)
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

function ProxyMacroClass:DisconnectAll()
	for Index=#self.Connections,1,-1 do
		local Connection = self.Connections[Index]
		if Connection then
			Connection:Disconnect()
		end
	end
end

function ProxyMacroClass:Destroy()
	self.Disabled=true
	if self.__MainProxyConnection then
		self.__MainProxyConnection:Disconnect()
		self.__MainProxyConnection = nil :: any
	end
	self.FireFilter:Destroy()
	self.FireFilter=nil :: any
	self.__ParseARGS=nil :: any
	self:DisconnectAll()
	setmetatable(self,nil)
end

-- Dispatcher Class

export type Dispatcher<T...> = {
	__Connections:{Connection<T...>},
	__PendingRemovedConnections:{Connection<T...>},
	__FireMode:number,
	Connections:number,
	Disabled:boolean, -- Stops (ANY) Fire from sending any signal.
	PublicDispatcher:PublicDispatcher<T...>, -- Public Dispatcher Blocks Any Fires, Only for Connecting.
	FireFilter:FireFilter<T...>, -- Used for Filtering Fire ARGS
	-- Debugger Tracer
	DebugTraceStack:{string}?,
	DebugTrace:(self:Dispatcher<T...>,Enabled:boolean)->(),
	-- Intercept
	CustomIntercept:(T...)->(T...)?, -- This Intercept Any (Fire) Method ARGS with an custom function (This SHOULD never yield and SHOULD return the input and to output!)
	HandleIntercept:(self:Dispatcher<T...>,Macro:DispatcherMacro<T...>,Header:(DispatcherMacro<T...>)->(),T...) -> (),
	SetCustomIntercept:(self:Dispatcher<T...>,Interceptor:(T...)->(T...)) -> (),
	LinkRBXSignal:(self:Dispatcher<T...>,RBX:RBXScriptSignal,Parallel:boolean?) -> (RBXScriptConnection),
	-- Main Fire Methods
	Fire:(self:Dispatcher<T...>,T...)->(boolean), -- defaults to threaded 
	FireDebug:(self:Dispatcher<T...>,T...)->(boolean), -- (Native) Outputs ALL Fire data via print for debugging only.
	FireHardware:(self:Dispatcher<T...>,T...)->(boolean), -- Unsafe, Native, No Header, No Intercept.
	FireNative:(self:Dispatcher<T...>,T...)->(boolean), -- Executes immediately on the same thread.
	FireDeferred:(self:Dispatcher<T...>,T...)->(boolean), -- Executes at the end of the current engine step.
	FireThreaded:(self:Dispatcher<T...>,T...)->(boolean), -- Wraps each listener in task.spawn.
	FirePCALL:(self:Dispatcher<T...>,T...)->(boolean), -- Wraps each listener in an pcall for error safety.
	FireStepped:(self:Dispatcher<T...>,TimeStep:number,T...)->(boolean), -- (FireHardware) but stepped per second
	FireParallel:(self:Dispatcher<T...>,ResyncAfter:boolean?,T...)->(boolean), -- (FireHardware) but stepped per second
	-- Connections Methods
	Connect:(self:Dispatcher<T...>,Macro:DispatcherMacro<T...>,UsePooling:boolean?)->(Connection<T...>),
	BulkConnect:(self:Dispatcher<T...>,Macros:{DispatcherMacro<T...>})->({Connection<T...>}),
	ProxyConnect:(self:Dispatcher<T...>,DefaultMacros:{DispatcherMacro<T...>}?,Runtime:Runtime)->(ProxyMacro<T...>),
	Once:(self:Dispatcher<T...>,Macro:DispatcherMacro<T...>)->(Connection<T...>),
	Wait:(self:Dispatcher<T...>,TimeUntilTimeout:number?,ContinueAfterTimeout:boolean?,Threaded:boolean?)->T...,
	-- Clean up Methods 
	DisconnectAll:(self:Dispatcher<T...>)->(),
	Destroy:(self:Dispatcher<T...>)->()
}

-- (Public) Connections Only --
export type PublicDispatcher<T...> = {
	Connect:(self:PublicDispatcher<T...>,Macro:DispatcherMacro<T...>)->(Connection<T...>),
	BulkConnect:(self:PublicDispatcher<T...>,Macros:{DispatcherMacro<T...>})->({Connection<T...>}),
	ProxyConnect:(self:PublicDispatcher<T...>,Macros:{DispatcherMacro<T...>},Runtime:Runtime)->(ProxyMacro<T...>),
	Once:(self:PublicDispatcher<T...>,Macro:DispatcherMacro<T...>)->(Connection<T...>),
	Wait:(self:PublicDispatcher<T...>,Threaded:boolean?)->T...,
}

local DispatcherClass = {} :: Dispatcher<...any>

function __DispatcherFire<T...>(self:Dispatcher<T...>,Method:Runtime,...:T...) : boolean
	local ConnectionsLen = #self.__Connections
	if self.Disabled or ConnectionsLen<1 or (not self.FireFilter:Run(...)) then return false end
	local Connections = self.__Connections
	if self.DebugTraceStack then
		table.insert(self.DebugTraceStack,debug.traceback("Dispatcher Fire Trace",3))
		if #self.DebugTraceStack>50 then table.remove(self.DebugTraceStack,1) end
	end
	self.__FireMode+=1
	if Method=="HARDWARE" then
		-- Hardware means we run that Macro without Header or Intercept
		__DispatcherRawFire(ConnectionsLen,Connections,nil :: any,(if self.CustomIntercept then self.CustomIntercept(...) else ...)::any)
	else
		local Header = RuntimeHeaders[Method]
		if not Header then warn(`Failed Match "{Method} with Runtime Headers."`) return false end
		__DispatcherRawFire(ConnectionsLen,Connections,Header,(if self.CustomIntercept then self.CustomIntercept(...) else ...)::any)
	end
	self.__FireMode-=1
	-- Clean up
	local PRC = self.__PendingRemovedConnections
	if self.__FireMode == 0 and #PRC > 0 then
		for Index = #PRC,1,-1 do
			local Connection = PRC[Index]
			if Connection then
				local CIndex = table.find(Connections,Connection)
				if CIndex then
					local CLen = #Connections
					Connections[CIndex] = Connections[CLen]
					Connections[CLen] = nil
					self.Connections -= 1 -- Decrement actual count
				end
				Connection:Disconnect()
			end
		end
		table.clear(PRC)
	end
	return true
end

-- (Dispatcher) Event/Signal Handler
function FuncSignal:CreateDispatcher<T...>(): Dispatcher<T...>
	local Locked = false
	local NewDispatcher = {
		Disabled=false,
		FireFilter=__CreateFireFilter(),
		DebugTraceStack=nil,
		Connections=0,
		__FireMode=0,
		__Connections = setmetatable({},{__mode="v"}),
		__PendingRemovedConnections={},
		PublicDispatcher = (nil :: any)
	} :: Dispatcher<T...>
	setmetatable(NewDispatcher,{
		__index = DispatcherClass,
		__newindex = function(Table,Key,Value) if not Locked or Key=="CustomIntercept" then rawset(Table,Key,Value) return Value end error(`Cannot Append {tostring(Key)} To Dispatcher.`,3) end,
	})
	-- Public Init Code Block --
	NewDispatcher.PublicDispatcher = setmetatable({
		Connect=function(_,Macro) return NewDispatcher:Connect(Macro) end,
		BulkConnect=function(_,Macros) return NewDispatcher:BulkConnect(Macros) end,
		ProxyConnect=function(_,Default,Runtime) return NewDispatcher:ProxyConnect(Default,Runtime) end,
		Once=function(_,Macro) return NewDispatcher:Once(Macro) end,
		Wait=function(_,Threaded) return NewDispatcher:Wait(Threaded) end
	},{__metatable = "Public-Dispatcher Metatable is locked."}) :: PublicDispatcher<T...>
	Locked=true
	return NewDispatcher
end

-- (Connect) Links your Function to the Dispatcher.
function DispatcherClass:Connect<T...>(Macro:DispatcherMacro<T...>,UsePooling) : Connection<T...>
	local NewConnection:Connection<T...>
	NewConnection = __CreateConnectionFromPool(Macro,function()
		if self.__FireMode>0 then
			table.insert(self.__PendingRemovedConnections::{Connection<T...>},NewConnection)
			return
		end
		local Connections = self.__Connections
		local Index = table.find(Connections::{Connection<T...>},NewConnection)
		if Index then
			local CLen = #Connections
			Connections[Index] = Connections[CLen]
			Connections[CLen] = nil
			self.Connections-=1
		end
	end,UsePooling)
	table.insert(self.__Connections::{Connection<T...>},NewConnection)
	self.Connections+=1
	return NewConnection
end

-- (LinkRBXSignal) Link RBX Signals to fire Dispatcher.
function DispatcherClass:LinkRBXSignal(RBX,Parallel)
	local RBXScriptSignal:RBXScriptConnection
	if Parallel then
		RBXScriptSignal=RBX:ConnectParallel(function(...)
			self:FireNative(...)
		end)
		else
		RBXScriptSignal=RBX:Connect(function(...)
			self:FireNative(...)
		end)
	end
	return RBXScriptSignal
end

-- (BatchConnect) Lets batch many functions into connections (split into many connections) 
function DispatcherClass:BulkConnect(MacroImport)
	local Connections = {}
	for _,Macro in MacroImport do
		local Connection = self:Connect(Macro)
		table.insert(Connections,Connection)
	end
	return Connections
end

-- ProxyConnect (ProxyMacro) - Lets you Link Many Functions into one connection.
function DispatcherClass:ProxyConnect<T...>(DefaultMacros,Runtime)
	local NewProxyMacro = {
		Connections={},
		Disabled=false,
		CurrentRuntime=(Runtime or "THREADED"),
		FireFilter=__CreateFireFilter()
	} :: PrivateProxyMacro
	setmetatable(NewProxyMacro,{
		__index = ProxyMacroClass,
	})
	NewProxyMacro.__ParseARGS=function(...:T...)
		local Intercept = self.CustomIntercept
		return if Intercept then Intercept(...) else ...
	end
	NewProxyMacro.__MainProxyConnection=self:Connect(function(...)
		NewProxyMacro:Fire(...)
	end)
	if DefaultMacros then
		NewProxyMacro:BulkConnect(DefaultMacros)
	end
	return NewProxyMacro
end

-- Connects Once, Removes After.
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

-- Yield The Current Thread until the next fire.  (Use 0 to disable timer.)
function DispatcherClass:Wait<T...>(TimeUntilTimeout,ContinueAfterTimeout,Threaded)
	local Thread = CR()
	local ContinueAfterTimeout = if ContinueAfterTimeout == nil then false else ContinueAfterTimeout
	local TimeUntilTimeout = (TimeUntilTimeout or 0)
	local Timer:thread?
	if TimeUntilTimeout>0 then
		Timer=task.delay(TimeUntilTimeout,function()
			if RS:IsStudio() then
				warn(`Funcsignal Dispatcher\nWait hit timeout window\n(Waited for {TimeUntilTimeout} Seconds.)`)
			end
			if not ContinueAfterTimeout then
				error("Dispatcher timeout window hit (Waited for {TimeUntilTimeout} Seconds.",3)
			end
			if Threaded then
				TS(Thread,nil)
			else
				TD(Thread,nil)
			end
		end)
	end
	self:Once(function(...:T...)
		if Timer then
			task.cancel(Timer)
			Timer=nil
		end
		if Threaded then
			TS(Thread,...)
		else
			TD(Thread,...)
		end
	end)
	return CY()
end

function DispatcherClass:HandleIntercept(Macro,Header,...)
	if self.CustomIntercept then
		Header(Macro,self.CustomIntercept(...))
	else
		Header(Macro,...)
	end
end

-- Main Dispatcher Fire Codeblock

-- (Fire) > Default To Threaded.
function DispatcherClass:Fire<T...>(...:T...) return self:FireThreaded(...) end
-- (HARDWARE) >Yields< Bypasses all headers/interceptors for raw native speed, Good For when every nanosecond counts. It bypasses the Interceptor and provides the rawest dispatch loop possible.
function DispatcherClass:FireHardware<T...>(...:T...) return __DispatcherFire(self,"HARDWARE",...) end
-- (NATIVE) >Yields< Executes immediately on the same thread, Good For Core logic & high-speed math.
function DispatcherClass:FireNative<T...>(...:T...) return __DispatcherFire(self,"NATIVE",...) end
-- (THREADED) >Non Yielding< Wraps each listener in task.spawn, Good For Independent, heavy processes.
function DispatcherClass:FireThreaded<T...>(...:T...) return __DispatcherFire(self,"THREADED",...) end
-- (DEFERRED) >Non Yielding< Wraps each listener in task.defer, Good For UI updates to ensure they don't block critical game logic frames.
function DispatcherClass:FireDeferred<T...>(...:T...) return __DispatcherFire(self,"DEFERRED",...) end
-- (PCALL) >Non Yielding< Wraps execution in a protected call, Good For 3rd-party code or unstable plugins.
function DispatcherClass:FirePCALL<T...>(...:T...) return __DispatcherFire(self,"PCALL",...) end
-- (PARALLEL) >Yields< Executes Each Connection in Parallel, Good For Good For Core logic & high-speed math.
function DispatcherClass:FireParallel<T...>(ResyncAfter,...:T...) __DispatcherFire(self,"PARALLEL",ResyncAfter,...) return true end
-- (STEPPED) >Yields< Executes Each Connection Per Step(Waits per step) and, Good For Debuging Event Usage
function DispatcherClass:FireStepped<T...>(StepTime,...:T...) __DispatcherFire(self,"STEPPED",StepTime,...) return true end
-- (DEBUG) >Yields< Executes immediately on the same thread, while outputing the function arguments, Good For Debuging Events Fire data.
function DispatcherClass:FireDebug<T...>(...:T...) return __DispatcherFire(self,"DEBUG",...) end

-- Drops Dispatcher All Connections
function DispatcherClass:DisconnectAll()
	for Index = #self.__Connections,1,-1 do
		local Connection  = self.__Connections[Index]
		if Connection then
			Connection:Disconnect()
		end
	end
	table.clear(self.__Connections)
end

-- Updates The Custom Intercept Input: (...) Output Must Return (...)
function DispatcherClass:SetCustomIntercept(Interceptor)
	self.CustomIntercept=Interceptor
end

function DispatcherClass:DebugTrace(Enabled)
	if Enabled then
		self.DebugTraceStack={}
	else
		self.DebugTraceStack=nil
	end	
end

-- Cleans up the Dispatcher.
function DispatcherClass:Destroy()
	self.Disabled=true
	self:DisconnectAll()
	self.FireFilter:Destroy()
	setmetatable(self,nil)
end

-- Returns Pool Size
function FuncSignal:GetConnectionsPoolSize()
	return #ConnectionsPool
end

-- Clears out the Connections Pool.
function FuncSignal:ClearConnectionsPool()
	table.clear(ConnectionsPool)
end

-- Preloads (X) Amount of Connections to pool. (MAX 500)
function FuncSignal:PreloadConnectionsToPool(Steps:number)
	for _=1,math.clamp(Steps,1,500) do
		__CreateConnection(nil::any,nil::any,true):Disconnect()
	end
	return #ConnectionsPool
end

-- Creates an Dispatcher for an RBXSignal.
function FuncSignal:CreateDispatcherLinkedRBX(RBXScriptSignal:RBXScriptSignal,Parallel:boolean?)
	local Dispatcher = FuncSignal:CreateDispatcher()
	local RBXSignal = Dispatcher:LinkRBXSignal(RBXScriptSignal,Parallel)
	return {
		Dispatcher=Dispatcher,
		RBXSignal=RBXSignal
	}
end

return FuncSignal
