const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const layout={};vm.createContext(layout);vm.runInContext(fs.readFileSync(__dirname+'/../CanvasLayout.js','utf8').replace('.pragma library',''),layout);
let checks=0;
for(const gap of [8,16,24,32,48,64]) {
  const placed=[];
  for(let i=0;i<30;i++) {
    const request={x:(i%3)*10,y:(i%5)*8,width:180+(i%4)*60,height:126+(i%3)*42};
    const safe=layout.avoidOverlap(request,placed,gap);
    assert(placed.every(o=>!layout.intersects(safe,o,gap-0.001)));
    placed.push(safe);checks++;
  }
  const original=placed[10],obstacles=placed.filter((_,i)=>i!==10);
  const resized=layout.avoidOverlap({...original,width:640,height:480},obstacles,gap);
  assert(obstacles.every(o=>!layout.intersects(resized,o,gap-0.001)));checks++;
  const untouched=layout.avoidOverlap(placed[0],placed.slice(1),gap);
  assert.equal(untouched.x,placed[0].x);assert.equal(untouched.y,placed[0].y);checks++;
}
console.log(`${checks} placement, minimum-gap, resize and stable-position checks passed`);

// At every zoom, pan limits must correspond to transformed rectangle edges.
for(const scale of [0.55,0.75,1,1.35,1.65]) {
 const rects=[{x:-170,y:-120,width:340,height:240},{x:194,y:20,width:252,height:176}];
 const view={left:24,top:80,right:1000,bottom:700};
 const plain=layout.panLimits(rects,scale,500,280,view);
 const loose=layout.panLimits(rects,scale,500,280,view,{x:32,y:180});
 assert.equal(loose.minY,plain.minY-180);assert.equal(loose.maxY,plain.maxY+180);
 const low=280-120*scale,high=280+196*scale;
 if(high-low<=620){assert.equal(plain.minY+low,80);assert.equal(plain.maxY+high,700);}
 else {assert.equal(plain.minY+high,700);assert.equal(plain.maxY+low,80);}
 checks++;
}
const small=layout.panLimits([{x:0,y:0,width:300,height:200}],0.55,500,280,{left:24,top:80,right:1000,bottom:700});
const large=layout.panLimits([{x:0,y:0,width:300,height:200}],1.65,500,280,{left:24,top:80,right:1000,bottom:700});
assert.notEqual(small.maxY,large.maxY);
console.log('Zoom-dependent bounds and 180pt vertical slack checks passed');

// Edge dragging must clamp dimensions while keeping the opposite edge fixed.
const bounds={minWidth:180,minHeight:126,maxWidth:640,maxHeight:480};
const start={x:40,y:60,width:240,height:168};
for(const edge of ['top','bottom','left','right','topleft','topright','bottomleft','bottomright']) {
 for(const dx of [-10000,-17,0,29,10000])for(const dy of [-10000,-11,0,37,10000]) {
  const r=layout.resizeRect(start,edge,dx,dy,bounds);
  assert(r.width>=180 && r.width<=640 && r.height>=126 && r.height<=480);
  if(edge.includes('left'))assert.equal(r.x+r.width,start.x+start.width);
  else assert.equal(r.x,start.x);
  if(edge.includes('top'))assert.equal(r.y+r.height,start.y+start.height);
  else assert.equal(r.y,start.y);
 }
}
const shelf=layout.shelfSizes([{width:180,height:126},{width:640,height:480},{width:240,height:168}],24);
assert.equal(shelf.width,1108);assert.equal(shelf.height,480);
assert.equal(shelf.positions[1].x,204);assert.equal(shelf.positions[2].x,868);
const custom=layout.spread(12,24,[{width:640,height:480},null,{width:180,height:126}]);
assert.equal(custom[0].width,640);assert.equal(custom[2].height,126);
for(let i=0;i<custom.length;i++)for(let j=i+1;j<custom.length;j++)assert(!layout.intersects(custom[i],custom[j],23.99));
console.log('200 edge-resize limits, fixed-edge anchors and variable-size layout checks passed');
