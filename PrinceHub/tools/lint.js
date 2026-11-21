// Static analysis: undefined globals, Luau register/local/upvalue limits, local shadowing in same scope
const fs=require('fs'),lp=require('luaparse');const {luauToLua}=require('./check.js');
const file=process.argv[2];const src=luauToLua(fs.readFileSync(file,'utf8'));
const ast=lp.parse(src,{luaVersion:'5.3',locations:true,scope:false,comments:false});
const KNOWN=new Set(('game workspace script Enum Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Ray RaycastParams TweenInfo NumberRange NumberSequence NumberSequenceKeypoint ColorSequence ColorSequenceKeypoint Rect Region3 BrickColor PhysicalProperties OverlapParams Font DateTime Random Axes Faces PathWaypoint task wait spawn delay tick time os math string table coroutine debug utf8 bit32 buffer typeof type pairs ipairs next select tostring tonumber print warn error assert pcall xpcall setmetatable getmetatable rawget rawset rawequal rawlen unpack require loadstring shared _G _VERSION newproxy gcinfo collectgarbage elapsedTime settings UserSettings plugin '+
 'getgenv getrenv getsenv getreg getgc getinstances getnilinstances getconnections firesignal fireclickdetector fireproximityprompt firetouchinterest hookfunction hookmetamethod newcclosure islclosure iscclosure checkcaller getnamecallmethod setnamecallmethod getrawmetatable setrawmetatable setreadonly isreadonly make_writeable make_readonly identifyexecutor getexecutorname syn fluxus KRNL_LOADED is_sirhurt_closure pebc_execute isfile readfile writefile appendfile delfile isfolder makefolder delfolder listfiles loadfile dofile request http_request http setclipboard toclipboard queue_on_teleport queueonteleport setfpscap getfpscap gethui get_hidden_gui gethiddenproperty sethiddenproperty sethiddenprop cloneref clonefunction getcustomasset getsynasset Drawing cleardrawcache isrenderobj setrenderproperty getrenderproperty mouse1click mouse1press mouse1release mouse2click mousemoveabs mousemoverel keypress keyrelease isrbxactive iswindowactive getthreadidentity setthreadidentity getidentity setidentity crypt base64 base64_encode base64_decode lz4compress lz4decompress getcallingscript getscriptclosure getscripthash getscriptbytecode decompile getupvalue getupvalues setupvalue getconstant getconstants setconstant getproto getprotos getstack setstack getinfo debug.getinfo sethiddenproperty setsimulationradius gethwid WebSocket messagebox rconsoleprint rconsolewarn rconsoleerr rconsoleclear rconsolename rconsoleinput printconsole consoleprint gethwid getscripts getrunningscripts getloadedmodules getcallbackvalue replicatesignal isnetworkowner restorefunction ').split(/\s+/).filter(Boolean));
const LIM_LOCALS=200,LIM_UP=200;
const report={undefGlobals:new Map(),globalWrites:new Map(),funcs:[],dupLocals:[]};
let globalsDefined=new Set();
function Scope(parent,fn){return{vars:new Map(),parent,fn};}
function Fn(parent,node){return{parent,node,active:0,max:0,ups:new Set(),name:''};}
let curFn=null,cur=null;
function declare(name,node){ if(cur.vars.has(name)&&cur.fn===curFn){} cur.vars.set(name,curFn);curFn.active++;if(curFn.active>curFn.max){curFn.max=curFn.active;curFn.maxLine=node.loc.start.line;} }
function lookup(name){let s=cur;while(s){if(s.vars.has(name))return s.vars.get(name);s=s.parent;}return null;}
function useName(name,line,write){const owner=lookup(name);
 if(!owner){ if(write){globalsDefined.add(name);if(!report.globalWrites.has(name))report.globalWrites.set(name,line);} else {if(!report.undefGlobals.has(name))report.undefGlobals.set(name,[]);report.undefGlobals.get(name).push(line);} return;}
 // upvalue capture: mark all fns between curFn and owner
 let f=curFn;while(f&&f!==owner){f.ups.add(name);f=f.parent;}
}
function pushScope(){cur=Scope(cur,curFn);}
function popScope(){curFn.active-=cur.vars.size;cur=cur.parent;}
function expr(n){ if(!n)return; switch(n.type){
 case 'Identifier':useName(n.name,n.loc.start.line,false);break;
 case 'FunctionDeclaration':func(n);break;
 case 'MemberExpression':expr(n.base);break;
 case 'IndexExpression':expr(n.base);expr(n.index);break;
 case 'CallExpression':expr(n.base);n.arguments.forEach(expr);break;
 case 'StringCallExpression':expr(n.base);break;
 case 'TableCallExpression':expr(n.base);expr(n.arguments);break;
 case 'TableConstructorExpression':n.fields.forEach(f=>{if(f.key&&f.type==='TableKey')expr(f.key);expr(f.value);});break;
 case 'BinaryExpression':case 'LogicalExpression':expr(n.left);expr(n.right);break;
 case 'UnaryExpression':expr(n.argument);break;
 default:break;}}
function func(n){ // name
 if(n.identifier){ if(n.isLocal){declare(n.identifier.name,n);} else if(n.identifier.type==='Identifier'){useName(n.identifier.name,n.loc.start.line,true);} else expr(n.identifier.base||n.identifier); }
 const f=Fn(curFn,n);f.name=n.identifier?(n.identifier.name||(n.identifier.identifier&&n.identifier.identifier.name)||'?'):'(anon)';f.line=n.loc.start.line;report.funcs.push(f);
 const savedFn=curFn,savedScope=cur;curFn=f;cur=Scope(savedScope,f);
 if(n.identifier&&n.identifier.indexer===':')declare('self',n);
 n.parameters.forEach(p=>{if(p.type==='Identifier')declare(p.name,p);});
 block(n.body);
 curFn=savedFn;cur=savedScope;}
function block(stmts){stmts.forEach(stmt);}
function stmt(n){switch(n.type){
 case 'LocalStatement':n.init.forEach(expr);n.variables.forEach(v=>declare(v.name,v));break;
 case 'AssignmentStatement':n.init.forEach(expr);n.variables.forEach(v=>{if(v.type==='Identifier')useName(v.name,v.loc.start.line,true);else expr(v);});break;
 case 'CallStatement':expr(n.expression);break;
 case 'FunctionDeclaration':func(n);break;
 case 'ReturnStatement':n.arguments.forEach(expr);break;
 case 'IfStatement':n.clauses.forEach(c=>{if(c.condition)expr(c.condition);pushScope();block(c.body);popScope();});break;
 case 'WhileStatement':expr(n.condition);pushScope();block(n.body);popScope();break;
 case 'DoStatement':pushScope();block(n.body);popScope();break;
 case 'RepeatStatement':pushScope();block(n.body);expr(n.condition);popScope();break;
 case 'ForNumericStatement':expr(n.start);expr(n.end);expr(n.step);pushScope();curFn.active+=3;declare(n.variable.name,n.variable);block(n.body);popScope();curFn.active-=3;break;
 case 'ForGenericStatement':n.iterators.forEach(expr);pushScope();curFn.active+=3;n.variables.forEach(v=>declare(v.name,v));block(n.body);popScope();curFn.active-=3;break;
 default:break;}}
curFn=Fn(null,ast);curFn.name='(main chunk)';curFn.line=1;report.funcs.push(curFn);cur=Scope(null,curFn);
block(ast.body);
const out={file};
out.undefined=[...report.undefGlobals].filter(([k])=>!KNOWN.has(k)&&!globalsDefined.has(k)).map(([k,v])=>({name:k,count:v.length,lines:v.slice(0,6)}));
out.writtenGlobals=[...report.globalWrites].map(([k,l])=>k+'@'+l);
out.heavy=report.funcs.filter(f=>f.max>150||f.ups.size>120).map(f=>({fn:f.name,line:f.line,maxLocals:f.max,atLine:f.maxLine,upvalues:f.ups.size}));
out.overLimit=report.funcs.filter(f=>f.max>LIM_LOCALS||f.ups.size>LIM_UP).map(f=>({fn:f.name,line:f.line,maxLocals:f.max,upvalues:f.ups.size}));
console.log(JSON.stringify(out,null,1));
