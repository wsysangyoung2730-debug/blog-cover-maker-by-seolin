import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const html=fs.readFileSync(path.join(root,'Reference/original.html'),'utf8');
const js=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const start=js.indexOf('const S=');
const end=js.indexOf('/* ---------- state & build');
const context=vm.createContext({document:{createElement:()=>({getContext:()=>({})})}});
const data=vm.runInContext(js.slice(start,end)+`;({templates:TPLS.map(t=>({id:t.id,name:t.name,category:t.cat,elements:t.make()})),themes:Object.entries(THEMES).map(([id,t])=>({id,...t})),titleFonts:Object.entries(FONTS).map(([id,t])=>({id,...t})),fonts:Object.entries(FF).map(([id,t])=>({id,...t})),defaults:Object.fromEntries(Object.entries(st).filter(([k])=>!['img','imgS'].includes(k)))})`,context,{timeout:2000});
// Native palette corrections keep saved theme IDs compatible with the HTML catalog.
const nativeThemes={
  r_blue:{dark:'#0D2363',main:'#2563EB',accent:'#79A3FF',paper:'#E4ECFC',ink:'#0D2363'},
  r_indigo:{dark:'#090F2C',main:'#172554',accent:'#33447A',paper:'#E4E7F1',ink:'#090F2C'}
};
for(const theme of data.themes) Object.assign(theme,nativeThemes[theme.id]??{});
fs.writeFileSync(path.join(root,'Sources/CoverCore/Resources/catalog.json'),JSON.stringify(data,null,2)+'\n');
const image=html.match(/class="logo"[\s\S]*?src="data:image\/png;base64,([^"]+)"/)[1];
fs.writeFileSync(path.join(root,'Sources/CoverCore/Resources/seolin-logo.png'),Buffer.from(image,'base64'));
console.log(`${data.templates.length} templates, ${data.themes.length} themes, ${data.fonts.length} fonts`);
