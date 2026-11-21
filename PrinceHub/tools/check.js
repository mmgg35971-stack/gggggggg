// Luau-aware syntax check: neutralize `continue` statements (Luau) then parse as Lua 5.3
const fs=require('fs'),lp=require('luaparse');

// mask strings/comments to find code-level `continue`
function luauToLua(s){
  let out='',i=0,n=s.length;
  while(i<n){
    const c=s[i];
    if(c==='-'&&s[i+1]==='-'){ // comment
      const m=s.slice(i+2).match(/^\[(=*)\[/);
      let j;
      if(m){const close=']'+m[1]+']';j=s.indexOf(close,i+2+m[0].length);j=j<0?n:j+close.length;}
      else{j=s.indexOf('\n',i);j=j<0?n:j;}
      out+=s.slice(i,j);i=j;continue;
    }
    if(c==='['){const m=s.slice(i).match(/^\[(=*)\[/);if(m){const close=']'+m[1]+']';let j=s.indexOf(close,i+m[0].length);j=j<0?n:j+close.length;out+=s.slice(i,j);i=j;continue;}}
    if(c==='"'||c==="'"){let j=i+1;while(j<n&&s[j]!==c){if(s[j]==='\\')j++;else if(s[j]==='\n')break;j++;}out+=s.slice(i,j+1);i=j+1;continue;}
    if(/[A-Za-z_]/.test(c)){let j=i;while(j<n&&/[A-Za-z0-9_]/.test(s[j]))j++;const w=s.slice(i,j);
      const prev=s[i-1]||' ';
      out+=(w==='continue'&&prev!=='.'&&prev!==':')?'do end':w;i=j;continue;}
    if('+-*/%^'.includes(c)&&s[i+1]==='='&&s[i+2]!=='='){out+='=';i+=2;continue;}
    if(c==='.'&&s[i+1]==='.'&&s[i+2]==='='&&s[i+3]!=='='){out+='=';i+=3;continue;}
    out+=c;i++;
  }
  return out;
}
module.exports={luauToLua};
if(require.main!==module)return;
const src=fs.readFileSync(process.argv[2],'utf8');const lua=luauToLua(src);
try{lp.parse(lua,{luaVersion:'5.3',comments:false,locations:false,labels:false});console.log('SYNTAX OK',process.argv[2]);}
catch(e){console.log('SYNTAX ERROR',e.message);process.exit(1);}
