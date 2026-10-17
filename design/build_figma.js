// Run using Figma use_figma against the file in figma-state.json.
// Original PocketFlow screen construction; no screenshots or external app assets.
const page = figma.root.children[0];
await figma.setCurrentPageAsync(page);
if (page.children.some(n => n.name === 'PocketFlow / Review')) {
  throw new Error('Review already exists. Inspect recorded IDs before updating.');
}
const created = [], mutated = [];
const track = node => { created.push(node.id); return node; };
const rgb = hex => ({r:parseInt(hex.slice(1,3),16)/255,g:parseInt(hex.slice(3,5),16)/255,b:parseInt(hex.slice(5,7),16)/255});
await Promise.all([
  {family:'Noto Sans SC',style:'Regular'}, {family:'Noto Sans SC',style:'Medium'},
  {family:'Noto Sans SC',style:'Bold'}, {family:'Inter',style:'Regular'},
  {family:'Inter',style:'Medium'}, {family:'Inter',style:'Semi Bold'},
].map(f => figma.loadFontAsync(f)));

// Adapted from the Figma skill's createVariableCollection helper.
async function createVariableCollection(name, modeNames) {
  const collection = figma.variables.createVariableCollection(name);
  const modeIds = {};
  collection.renameMode(collection.modes[0].modeId, modeNames[0]);
  modeIds[modeNames[0]] = collection.modes[0].modeId;
  for (let i=1;i<modeNames.length;i++) modeIds[modeNames[i]]=collection.addMode(modeNames[i]);
  return {collection,modeIds};
}
const {collection,modeIds} = await createVariableCollection('PocketFlow', ['Light']);
const mode = modeIds.Light, tokens = {}, variables = [];
function variable(name,type,value,scopes) {
  const v=figma.variables.createVariable(name,collection,type);
  v.scopes=scopes; v.setValueForMode(mode,value);
  v.setVariableCodeSyntax('ANDROID',name.replaceAll('/','_'));
  variables.push({id:v.id,name,scopes}); return v;
}
const palette={bg:'#F5F6F2',surface:'#FFFFFF',ink:'#202D27',muted:'#64736B',primary:'#2E6B58',hero:'#153E35',soft:'#E7EEE5',onHero:'#F6FAF4',lime:'#D6E4A7',line:'#DCE3DC',amber:'#A77536',rose:'#AE655D',blue:'#758F9A'};
for(const [name,hex] of Object.entries(palette)) {
  const p=variable('primitive/'+name,'COLOR',{...rgb(hex),a:1},[]);
  tokens[name]=variable('color/'+name,'COLOR',{type:'VARIABLE_ALIAS',id:p.id},['FRAME_FILL','SHAPE_FILL','TEXT_FILL','STROKE_COLOR']);
}
for(const n of [4,8,12,16,20,24,32]) tokens['s'+n]=variable('spacing/'+n,'FLOAT',n,['GAP']);
for(const n of [12,16,24,32]) tokens['r'+n]=variable('radius/'+n,'FLOAT',n,['CORNER_RADIUS']);
function paint(key) { return figma.variables.setBoundVariableForPaint({type:'SOLID',color:rgb(palette[key])},'color',tokens[key]); }
function fill(node,key) { node.fills=[paint(key)]; }
function radius(node,n) { for(const k of ['topLeftRadius','topRightRadius','bottomLeftRadius','bottomRightRadius']) node.setBoundVariable(k,tokens['r'+n]); }
function spacing(node,n,pad=0) {
  node.setBoundVariable('itemSpacing',tokens['s'+n]);
  if(pad) for(const k of ['paddingLeft','paddingRight','paddingTop','paddingBottom']) node.setBoundVariable(k,tokens['s'+pad]);
}
const styles={};
for(const [name,size,family,weight] of [
  ['caption',12,'Noto Sans SC','Regular'],['body',14,'Noto Sans SC','Regular'],
  ['label',14,'Noto Sans SC','Medium'],['section',16,'Noto Sans SC','Bold'],
  ['title',24,'Noto Sans SC','Bold'],['board',32,'Noto Sans SC','Bold'],
  ['number',24,'Inter','Semi Bold'],['largeNumber',52,'Inter','Semi Bold'],
  ['key',24,'Inter','Medium'],['brand',20,'Inter','Semi Bold'],
]) { const s=figma.createTextStyle();s.name='PocketFlow/'+name;s.fontName={family,style:weight};s.fontSize=size;s.lineHeight={unit:'PERCENT',value:family==='Inter'?120:150};styles[name]=s; }
function text(parent,value,role='body',color='ink',width) {
  const n=track(figma.createText()); n.name=value;n.textStyleId=styles[role].id;n.characters=value;fill(n,color);
  parent.appendChild(n); if(width){n.textAutoResize='HEIGHT';n.resize(width,n.height);}return n;
}
function box(parent,name,width,height,direction='VERTICAL',gap=8,pad=0,color) {
  const n=track(figma.createAutoLayout(direction));n.name=name;n.fills=[];spacing(n,gap,pad);parent.appendChild(n);
  if(width&&height){n.resize(width,height);n.layoutSizingHorizontal='FIXED';n.layoutSizingVertical='FIXED';}
  else if(width){n.resize(width,1);n.layoutSizingHorizontal='FIXED';n.layoutSizingVertical='HUG';}
  if(color)fill(n,color);return n;
}
function rule(parent,width,color='line',height=1){const n=track(figma.createRectangle());n.resize(width,height);fill(n,color);parent.appendChild(n);return n;}

const right=page.children.reduce((v,n)=>Math.max(v,n.x+n.width),0);
const masters=box(page,'PocketFlow / Components',390,undefined,'VERTICAL',16,24,'surface');masters.x=right+100;masters.y=1500;
text(masters,'PocketFlow · 复用组件','section');
const components={};
function component(name,width,height,direction='HORIZONTAL',color='surface',pad=8,gap=8) {
  const c=track(figma.createComponent());c.name=name;c.description='PocketFlow 原生界面复用元素';c.layoutMode=direction;c.resize(width,height);c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';spacing(c,gap,pad);fill(c,color);masters.appendChild(c);return c;
}
function expose(c,node,label,value){const key=c.addComponentProperty(label,'TEXT',value);node.componentPropertyReferences={characters:key};return key;}
function instance(c,parent,props={}){const i=track(c.createInstance());parent.appendChild(i);if(Object.keys(props).length)i.setProperties(props);return i;}
const row=component('Transaction row',342,52,'HORIZONTAL','surface',8,12);radius(row,12);row.counterAxisAlignItems='CENTER';
const badge=box(row,'Category',36,36,'HORIZONTAL',4,0,'soft');radius(badge,12);badge.primaryAxisAlignItems='CENTER';badge.counterAxisAlignItems='CENTER';
const badgeKey=expose(row,text(badge,'餐','label','primary'),'Category','餐');
const details=box(row,'Details',202,undefined,'VERTICAL',4);const titleKey=expose(row,text(details,'食堂午餐','label'),'Title','食堂午餐');const detailKey=expose(row,text(details,'今天 12:20 · 餐饮','caption','muted'),'Detail','今天 12:20 · 餐饮');
const amountKey=expose(row,text(row,'−18.00','label'),'Amount','−18.00');components.row={id:row.id,badgeKey,titleKey,detailKey,amountKey};

const icons={};
const paths={home:'M3 10 12 3l9 7v10h-6v-6H9v6H3Z',book:'M5 4h14v16H5Zm4 5h6M9 13h6',chart:'M4 20V10m8 10V4m8 16v-7',settings:'M9 4h6l1 3 3 1 2 5-2 3-3 1-1 3H9l-1-3-3-1-2-5 2-3 3-1Z M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0'};
for(const [name,path] of Object.entries(paths)) {
  const c=component('Icon/'+name,24,24,'HORIZONTAL','surface',0,4);c.fills=[];
  const svg=track(figma.createNodeFromSvg('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="'+path+'" stroke="#2E6B58" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/></svg>'));c.appendChild(svg);icons[name]=c;
}
const navVariants=[];
for(const active of [false,true]) {
  const c=component('Active='+active,108,64,'VERTICAL',active?'soft':'surface',8,4);radius(c,16);c.counterAxisAlignItems='CENTER';
  const iconNode=instance(icons.home,c);
  const labelNode=text(c,'首页','caption',active?'primary':'muted');navVariants.push({c,labelNode,iconNode});
}
const navSet=track(figma.combineAsVariants(navVariants.map(x=>x.c),masters));navSet.name='Navigation item';navSet.layoutMode='HORIZONTAL';spacing(navSet,16,8);navSet.resize(240,80);
const navLabelKey=navSet.addComponentProperty('Label','TEXT','首页');
const navIconKey=navSet.addComponentProperty('Icon','INSTANCE_SWAP',icons.home.id);
for(const v of navVariants){v.labelNode.componentPropertyReferences={characters:navLabelKey};v.iconNode.componentPropertyReferences={mainComponent:navIconKey};v.labelKey=navLabelKey;v.iconKey=navIconKey;}
components.nav=navVariants.map(x=>({id:x.c.id,labelKey:x.labelKey,iconKey:x.iconKey}));

// Reuse Material 3 Button; override only brand and Chinese text styling.
const m3=await figma.importComponentSetByKeyAsync('ab924dce8b851fd820bd0d56da24a9c489311ae6');
const m3base=m3.children.find(n=>n.name==='Type=Round, Size=Medium, State=Enabled');
if(!m3base)throw new Error('Expected Material 3 medium button variant missing');
const buttonProps=m3.componentPropertyDefinitions;
const m3Label=Object.keys(buttonProps).find(k=>buttonProps[k].type==='TEXT');
const m3Icon=Object.keys(buttonProps).find(k=>k.startsWith('Show icon'));
const sourceFonts=m3base.findAllWithCriteria({types:['TEXT']}).flatMap(n=>n.getStyledTextSegments(['fontName']).map(s=>s.fontName));
await Promise.all(sourceFonts.map(f=>figma.loadFontAsync(f)));
function button(parent,label) {
  const i=instance(m3base,parent,{[m3Label]:label,[m3Icon]:false});i.resize(342,56);fill(i,'primary');
  for(const t of i.findAllWithCriteria({types:['TEXT']})){t.textStyleId=styles.label.id;fill(t,'onHero');}
  return i;
}

const board=box(page,'PocketFlow / Review',undefined,undefined,'VERTICAL',24,32,'bg');board.x=right+100;board.y=0;
text(board,'PocketFlow','board');text(board,'让每一笔生活费，都花得心中有数。','section','muted');
text(board,'Android · 中文 · 离线优先     /     以下均为设计示例数据，非真实账单','caption','muted');
const screensRow=box(board,'Four screens',undefined,undefined,'HORIZONTAL',24);
const screens=[],navLinks=[],buttons=[];
function phone(name,index) {
  const column=box(screensRow,name+' / Column',390,undefined,'VERTICAL',12);text(column,'0'+(index+1)+'  '+name,'section');
  const screen=box(column,name,390,844,'VERTICAL',4,0,'bg');screen.itemSpacing=0;radius(screen,24);screen.clipsContent=true;
  const status=box(screen,'Android status',390,32,'HORIZONTAL',8,0,'bg');status.paddingLeft=24;status.paddingRight=24;status.counterAxisAlignItems='CENTER';status.primaryAxisAlignItems='SPACE_BETWEEN';text(status,'9:41','caption');text(status,'5G  ▰','caption');
  const header=box(screen,'Header',390,72,'HORIZONTAL',8,24,'bg');header.paddingTop=12;header.paddingBottom=12;header.counterAxisAlignItems='CENTER';header.primaryAxisAlignItems='SPACE_BETWEEN';text(header,name==='首页'?'PocketFlow':name,name==='首页'?'brand':'title');text(header,'2026年10月 ▾','caption','muted');
  const content=box(screen,'Content',390,660,'VERTICAL',index===0?16:12,24);content.clipsContent=false;
  const nav=box(screen,'Navigation',390,80,'HORIZONTAL',8,0,'surface');nav.primaryAxisAlignItems='CENTER';nav.counterAxisAlignItems='CENTER';
  for(const [j,label] of ['首页','统计','设置'].entries()) {
    const selected=(index===0&&j===0)||(index===2&&j===1)||(index===3&&j===2);const v=navVariants.find(x=>x.c.name==='Active='+selected);
    const i=instance(v.c,nav,{[v.labelKey]:label,[v.iconKey]:icons[['home','chart','settings'][j]].id});navLinks.push({node:i,target:[0,2,3][j]});
  }
  screens.push(screen);return content;
}

const home=phone('首页',0);
const hero=box(home,'Daily allowance hero',342,228,'VERTICAL',4,24,'hero');radius(hero,24);
text(hero,'从今天起 · 每日可支配','label','onHero');
const amount=box(hero,'60 yuan',294,64,'HORIZONTAL',8);amount.counterAxisAlignItems='CENTER';text(amount,'¥','number','lime');text(amount,'60.00','largeNumber','onHero');text(amount,'/ 天','body','onHero');
text(hero,'包含今天，距离月底还有 15 天','caption','onHero');rule(hero,294,'primary');
const metrics=box(hero,'Monthly metrics',294,48,'HORIZONTAL',24);for(const [label,value] of [['本月预算','1,500.00'],['累计支出','600.00'],['剩余预算','900.00']]){const m=box(metrics,label,82,undefined,'VERTICAL',4);text(m,label,'caption','onHero');text(m,value,'label','onHero');}
const progress=box(hero,'Budget used 40%',294,4,'HORIZONTAL',4,0,'primary');progress.itemSpacing=0;rule(progress,117.6,'lime',4);
const add=button(home,'＋  记一笔');buttons.push({id:add.id,target:1});
const latest=box(home,'Recent heading',342,24,'HORIZONTAL',8);latest.primaryAxisAlignItems='SPACE_BETWEEN';text(latest,'最近消费','section');text(latest,'今日合计 ¥38.00','caption','muted');
const tx=box(home,'Recent transactions',342,undefined,'VERTICAL',4);tx.itemSpacing=0;
for(const [cat,title,detail,value] of [['餐','食堂午餐','今天 12:20 · 餐饮','−18.00'],['饮','一杯拿铁','今天 09:30 · 饮品','−12.00'],['行','地铁出行','今天 08:10 · 交通','−8.00']]) instance(row,tx,{[badgeKey]:cat,[titleKey]:title,[detailKey]:detail,[amountKey]:value});

const record=phone('记一笔',1);
const input=box(record,'Amount input',342,88,'VERTICAL',4);text(input,'支出金额','caption','muted');text(input,'¥ 18.00','largeNumber');
const category=box(record,'Category selector',342,88,'VERTICAL',8);for(const labels of [['餐饮','饮品','购物','交通'],['学习','娱乐','医疗','其他']]){const r=box(category,'Category row',342,40,'HORIZONTAL',8);for(const label of labels){const chip=box(r,label,79.5,40,'HORIZONTAL',4,0,label==='餐饮'?'soft':'surface');radius(chip,12);chip.counterAxisAlignItems='CENTER';chip.primaryAxisAlignItems='CENTER';text(chip,label,'label',label==='餐饮'?'primary':'muted');}}
const metadata=box(record,'Date and note',342,48,'HORIZONTAL',12,12,'surface');radius(metadata,12);metadata.counterAxisAlignItems='CENTER';text(metadata,'10月17日 · 12:20','body');text(metadata,'添加备注','body','muted');
text(record,'记录完成后，每日额度将更新为 ¥58.80','caption','primary');
const keyboard=box(record,'Numeric keypad',342,undefined,'VERTICAL',4);for(const labels of [['1','2','3'],['4','5','6'],['7','8','9'],['.','0','⌫']]){const r=box(keyboard,'Keypad row',342,44,'HORIZONTAL',4);for(const label of labels){const key=box(r,'Key '+label,111.3,44,'HORIZONTAL',4,0,'surface');radius(key,12);key.primaryAxisAlignItems='CENTER';key.counterAxisAlignItems='CENTER';text(key,label,'key');}}
button(record,'保存支出');text(record,'默认今天 · 金额与分类必填','caption','muted');

const stats=phone('统计',2);
const total=box(stats,'Monthly total',342,64,'HORIZONTAL',24);total.counterAxisAlignItems='CENTER';const st=box(total,'Total labels',200,undefined,'VERTICAL',4);text(st,'本月累计支出','caption','muted');text(st,'¥600.00','number');text(total,'预算已用 40%','caption','primary');
const categoryCard=box(stats,'Category breakdown',342,188,'VERTICAL',8,16,'surface');radius(categoryCard,16);text(categoryCard,'钱花在哪里','section');
const cr=box(categoryCard,'Donut and legend',310,124,'HORIZONTAL',16);cr.counterAxisAlignItems='CENTER';
const donut=track(figma.createFrame());donut.name='Category donut';donut.resize(116,116);donut.fills=[];cr.appendChild(donut);
let angle=-Math.PI/2;for(const [value,color] of [[360,'primary'],[90,'amber'],[60,'blue'],[90,'rose']]){const e=track(figma.createEllipse());donut.appendChild(e);e.resize(116,116);e.arcData={startingAngle:angle,endingAngle:angle+2*Math.PI*value/600,innerRadius:0.73};fill(e,color);angle+=2*Math.PI*value/600;}
const center=text(donut,'¥600','label');center.x=(116-center.width)/2;center.y=(116-center.height)/2;
const legend=box(cr,'Legend',178,undefined,'VERTICAL',4);for(const [label,value,color] of [['餐饮','360 · 60%','primary'],['饮品','90 · 15%','amber'],['交通','60 · 10%','blue'],['其他','90 · 15%','rose']]){const r=box(legend,label,178,22,'HORIZONTAL',8);r.counterAxisAlignItems='CENTER';rule(r,8,color,8);text(r,label,'caption');text(r,'¥'+value,'caption','muted');}
const daily=box(stats,'Daily spending',342,146,'VERTICAL',8,16,'surface');radius(daily,16);text(daily,'每日消费 · 最近 7 天','section');
const bars=box(daily,'Bars',310,56,'HORIZONTAL',16);bars.counterAxisAlignItems='MAX';for(const [i,value] of [20,38,25,42,33,24,38].entries()){const b=box(bars,'Day '+(11+i),30,56,'VERTICAL',4);b.primaryAxisAlignItems='MAX';text(b,String(value),'caption','muted');rule(b,30,value===38&&i===6?'primary':'soft',Math.max(4,value*0.7));}
text(daily,'11       12       13       14       15       16       17日','caption','muted');
const trend=box(stats,'Budget evolution',342,160,'VERTICAL',8,16,'surface');radius(trend,16);text(trend,'剩余预算 · 消费节奏参考','section');
const expenses=[42,32,40,38,35,44,34,41,38,36,20,38,25,42,33,24,38];let balance=1500;const values=[1500,...expenses.map(v=>balance-=v)];
const actual=values.map((v,i)=>(10+i*9.35).toFixed(1)+','+(68-(v/1500)*56).toFixed(1)).join(' ');
const graph=track(figma.createNodeFromSvg('<svg xmlns="http://www.w3.org/2000/svg" width="310" height="70" viewBox="0 0 310 70"><path d="M10 68H300" stroke="#DCE3DC"/><path d="M10 12L300 68" stroke="#A77536" stroke-dasharray="5 4" fill="none"/><polyline points="'+actual+'" stroke="#2E6B58" stroke-width="2.5" fill="none"/><circle cx="169" cy="34.4" r="3" fill="#2E6B58"/></svg>'));trend.appendChild(graph);
text(trend,'实线：实际余额 ¥900   虚线：均匀消费参考','caption','muted');

const settings=phone('设置',3);
spacing(settings,8,24);
const budget=box(settings,'Budget settings card',342,96,'VERTICAL',8,16,'soft');radius(budget,16);text(budget,'本月生活费预算','caption','primary');const budgetRow=box(budget,'Budget amount',310,32,'HORIZONTAL',24);budgetRow.primaryAxisAlignItems='SPACE_BETWEEN';text(budgetRow,'¥1,500.00','number','hero');text(budgetRow,'修改预算  ›','label','primary');
function settingGroup(title,items){text(settings,title,'section');const group=box(settings,title+' group',342,undefined,'VERTICAL',4);group.itemSpacing=0;for(const [label,detail,cat] of items)instance(row,group,{[titleKey]:label,[detailKey]:detail,[amountKey]:'›',[badgeKey]:cat});}
settingGroup('生活费管理',[['月预算管理','调整当前及未来月份预算','预'],['历史月份','按月查看消费与结余','月']]);
settingGroup('数据管理',[['导出 Markdown 月报','整理账单，方便交给 AI 分析','MD'],['JSON 数据备份','保存全部账单与预算','备'],['恢复数据备份','预览内容后再恢复','回']]);
const privacy=box(settings,'Privacy note',342,68,'VERTICAL',4,12,'soft');radius(privacy,12);text(privacy,'数据留在你的手机里','label','primary');text(privacy,'无需账号，仅在你选择分享时导出文件。','caption','muted');

for(const link of [...navLinks,...buttons.map(b=>({node:screens.flatMap(s=>s.findAllWithCriteria({types:['INSTANCE']})).find(n=>n.id===b.id),target:b.target}))]){
  await link.node.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:screens[link.target].id,navigation:'NAVIGATE',transition:{type:'DISSOLVE',duration:0.2,easing:{type:'EASE_OUT'}}}]}]);mutated.push(link.node.id);
}
text(board,'关键状态 · 不用负额度制造困惑','section');
const states=box(board,'State examples',undefined,undefined,'HORIZONTAL',24);
for(const [name,value,note,color] of [['未设置预算','待设置','仍可记账；设置后显示每日额度。','primary'],['预算超支','¥0.00 / 天','已超支 ¥80.00，保留真实负余额。','rose'],['历史月份','结余 ¥125.00','展示整月结余，隐藏今日每日额度。','primary']]){const card=box(states,name,526,124,'VERTICAL',8,16,'surface');radius(card,16);text(card,name,'caption','muted');text(card,value,'title',color);text(card,note,'body','muted');}
text(board,'原型支持底部导航与首页“记一笔”跳转；键盘、保存、月份切换和导出按钮用于展示布局，未模拟业务操作。','caption','muted');
const descendants=board.findAll(()=>true);const counts={};for(const n of descendants)counts[n.type]=(counts[n.type]||0)+1;
const fontFamilies=[...new Set(descendants.filter(n=>n.type==='TEXT').flatMap(n=>n.getStyledTextSegments(['fontName']).map(s=>s.fontName.family)))];
return {createdNodeIds:created,mutatedNodeIds:mutated,fileKey:figma.fileKey,pageId:page.id,boardId:board.id,mastersId:masters.id,screens:screens.map(n=>({id:n.id,name:n.name,width:n.width,height:n.height})),collectionId:collection.id,variables,components,styles:Object.entries(styles).map(([name,s])=>({id:s.id,name})),counts,fontFamilies,descendants:descendants.length,images:descendants.filter(n=>Array.isArray(n.fills)&&n.fills.some(f=>f.type==='IMAGE')).map(n=>({id:n.id,name:n.name,type:n.type,width:n.width,height:n.height})),prototypeLinks:navLinks.length+buttons.length};
