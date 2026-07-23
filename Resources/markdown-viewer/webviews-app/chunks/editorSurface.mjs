import{H as F,ad as o,d as x,c as B,a3 as K,R as T,U as H,V as R,G as W,B as z,D as I,Z as $,q as G,s as q,Q as O,S as A,a6 as U,a0 as V,t as _,y as j,a7 as Y,W as Q,K as Z,$ as J,C as h,h as X,a2 as ee,a4 as re,x as te,ab as oe}from"./editor-vendor.mjs";import{i as ne}from"./installWebviewStyles.mjs";import"./vendor.mjs";const y=new Set;typeof window<"u"&&(window.cmuxEditorBridge={receive(r){for(const e of y)e(r)}});function ae(r){return y.add(r),()=>{y.delete(r)}}let w=0;async function v(r,e={}){const t=typeof window>"u"?void 0:window.webkit?.messageHandlers?.cmuxEditor;if(!t||typeof t.postMessage!="function")throw new Error("Native editor bridge is unavailable.");w+=1;const a=await t.postMessage({id:`editor-${w}`,method:r,params:e});if(!a.ok)throw new Error(a.error?.userMessage||"Native editor bridge request failed.");return a.value}class ie{baseline;pendingConflict=!1;constructor(e){this.baseline=e}isDirty(e){return e!==this.baseline}hasPendingConflict(){return this.pendingConflict}diskContent(){return this.baseline}applyExternal(e,t){const a=e===this.baseline;return this.baseline=t,t===e?(this.pendingConflict=!1,{kind:"none"}):a?(this.pendingConflict=!1,{kind:"replaceBuffer",content:t}):(this.pendingConflict=!0,{kind:"showConflict"})}noteSaved(e){this.baseline=e,this.pendingConflict=!1}resolveConflictReload(){return this.pendingConflict=!1,this.baseline}resolveConflictKeepMine(){this.pendingConflict=!1}}function M(r){return!!(r&&typeof r.foreground=="string"&&r.foreground.trim()!==""&&Array.isArray(r.palette)&&r.palette.length>=8)}function ce(r){const e=r.palette??[],t=(a,l)=>{const c=e[a];return typeof c=="string"&&c.trim()!==""?c:l??r.foreground};return{comment:t(8),string:t(2),constant:t(3),keyword:t(5),functionName:t(4),typeName:t(6),invalid:t(9,t(1)),heading:t(12,t(4)),strong:t(11,t(3)),emphasis:t(13,t(5)),raw:t(10,t(2)),link:t(14,t(6)),quote:t(8)}}function se(r){const e=ce(r);return F.define([{tag:o.comment,color:e.comment,fontStyle:"italic"},{tag:[o.string,o.special(o.string),o.character,o.attributeValue],color:e.string},{tag:[o.number,o.bool,o.null,o.atom,o.literal,o.unit],color:e.constant},{tag:[o.keyword,o.modifier,o.operatorKeyword,o.controlKeyword,o.definitionKeyword,o.moduleKeyword,o.self],color:e.keyword},{tag:[o.function(o.variableName),o.function(o.propertyName),o.macroName],color:e.functionName},{tag:[o.typeName,o.className,o.namespace,o.tagName],color:e.typeName},{tag:o.invalid,color:e.invalid},{tag:o.heading,color:e.heading,fontWeight:"bold"},{tag:o.strong,color:e.strong,fontWeight:"bold"},{tag:o.emphasis,color:e.emphasis,fontStyle:"italic"},{tag:o.monospace,color:e.raw},{tag:[o.link,o.url],color:e.link},{tag:o.quote,color:e.quote,fontStyle:"italic"}])}const le=100,de=`
  * {
    box-sizing: border-box;
  }
  html, body {
    margin: 0;
    height: 100%;
    background: transparent;
    overscroll-behavior: none;
  }
  #root {
    display: flex;
    flex-direction: column;
    height: 100%;
  }
  button, input {
    font: inherit;
  }
  button {
    cursor: default;
  }
  .cmux-editor-banner {
    display: none;
    align-items: center;
    gap: 8px;
    min-height: 30px;
    padding: 4px 12px;
    font: 11px -apple-system, system-ui, sans-serif;
    color: var(--cmux-editor-fg, #000);
    background: var(--cmux-editor-surface, rgba(127, 127, 127, 0.15));
    border-bottom: 1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25));
  }
  .cmux-editor-banner.cmux-editor-banner-visible {
    display: flex;
  }
  .cmux-editor-banner-message {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .cmux-editor-banner-error {
    background: color-mix(in srgb, var(--cmux-editor-danger, #b3261e) 11%, transparent);
    border-bottom-color: color-mix(in srgb, var(--cmux-editor-danger, #b3261e) 46%, transparent);
  }
  .cmux-editor-banner-error .cmux-editor-banner-message {
    color: color-mix(in srgb, var(--cmux-editor-danger, #b3261e) 88%, var(--cmux-editor-fg, #000));
  }
  .cmux-editor-banner button {
    font: inherit;
    padding: 3px 10px;
    border-radius: 5px;
    border: none;
    background: transparent;
    color: var(--cmux-editor-fg, #000);
  }
  .cmux-editor-banner button:hover {
    background: color-mix(in srgb, var(--cmux-editor-fg, currentColor) 8%, transparent);
  }
  .cmux-editor-banner button:active {
    background: color-mix(in srgb, var(--cmux-editor-fg, currentColor) 14%, transparent);
  }
  .cmux-editor-banner button.cmux-editor-banner-primary {
    background: var(--cmux-editor-accent-soft, rgba(127, 127, 127, 0.18));
    color: var(--cmux-editor-fg, #000);
  }
  .cmux-editor-banner button.cmux-editor-banner-primary:hover {
    background: color-mix(in srgb, var(--cmux-editor-accent, currentColor) 30%, transparent);
  }
  .cmux-editor-banner button:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--cmux-editor-fg, currentColor) 36%, transparent);
    outline-offset: 1px;
  }
  .cmux-editor-container {
    flex: 1;
    min-height: 0;
  }
  .cmux-editor-container .cm-editor {
    height: 100%;
  }
`,ue=x.theme({"&":{backgroundColor:"var(--cmux-editor-bg, transparent)",color:"var(--cmux-editor-fg, inherit)",fontSize:"var(--cmux-editor-font-size, 12px)"},"&.cm-focused":{outline:"none"},".cm-scroller":{fontFamily:"var(--cmux-editor-font-family, ui-monospace, 'SF Mono', Menlo, monospace)",lineHeight:"1.5",scrollbarWidth:"thin",scrollbarColor:"color-mix(in srgb, var(--cmux-editor-muted, currentColor) 28%, transparent) transparent"},".cm-content":{caretColor:"var(--cmux-editor-caret, var(--cmux-editor-fg, auto))"},".cm-gutters":{backgroundColor:"transparent",color:"var(--cmux-editor-muted, inherit)",border:"none"},".cm-activeLineGutter":{backgroundColor:"transparent",color:"var(--cmux-editor-fg, inherit)"},".cm-activeLine":{backgroundColor:"color-mix(in srgb, var(--cmux-editor-fg, currentColor) 5%, transparent)"},"&.cm-focused .cm-cursor":{borderLeftColor:"var(--cmux-editor-caret, var(--cmux-editor-fg, auto))"},"&.cm-focused > .cm-scroller .cm-selectionLayer .cm-selectionBackground, .cm-selectionBackground, & ::selection":{backgroundColor:"var(--cmux-editor-selection, var(--cmux-editor-accent-soft, rgba(0, 122, 255, 0.2))) !important"},".cm-selectionMatch":{backgroundColor:"color-mix(in srgb, var(--cmux-editor-fg, currentColor) 12%, transparent)"},".cm-searchMatch":{backgroundColor:"color-mix(in srgb, var(--cmux-editor-accent, currentColor) 25%, transparent)"},".cm-searchMatch.cm-searchMatch-selected":{backgroundColor:"color-mix(in srgb, var(--cmux-editor-accent, currentColor) 45%, transparent)",outline:"1px solid var(--cmux-editor-accent, currentColor)"},"&.cm-focused .cm-matchingBracket":{backgroundColor:"color-mix(in srgb, var(--cmux-editor-fg, currentColor) 15%, transparent)",outline:"1px solid color-mix(in srgb, var(--cmux-editor-fg, currentColor) 30%, transparent)"},"&.cm-focused .cm-nonmatchingBracket":{backgroundColor:"color-mix(in srgb, var(--cmux-editor-danger, currentColor) 30%, transparent)"},".cm-foldPlaceholder":{backgroundColor:"color-mix(in srgb, var(--cmux-editor-fg, currentColor) 10%, transparent)",border:"1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25))",color:"var(--cmux-editor-muted, inherit)",borderRadius:"4px",padding:"0 4px"},".cm-foldGutter span":{opacity:"0",transition:"opacity 0.1s"},".cm-gutters:hover .cm-foldGutter span":{opacity:"1"},".cm-dropCursor":{borderLeftColor:"var(--cmux-editor-caret, var(--cmux-editor-fg, currentColor))"},".cm-specialChar":{color:"var(--cmux-editor-danger, inherit)"},".cm-panels":{backgroundColor:"var(--cmux-editor-panel, Canvas)",color:"var(--cmux-editor-fg, inherit)",border:"none",font:"11px -apple-system, system-ui, sans-serif"},".cm-panels.cm-panels-top":{borderBottom:"1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25))"},".cm-panels.cm-panels-bottom":{borderTop:"1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25))"},".cm-panel.cm-search":{padding:"5px 12px 6px 8px"},".cm-panels .cm-textfield":{backgroundColor:"var(--cmux-editor-input, color-mix(in srgb, var(--cmux-editor-fg, currentColor) 7%, transparent))",border:"1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25))",borderRadius:"5px",padding:"3px 8px",color:"var(--cmux-editor-fg, inherit)",font:"inherit",outline:"none"},".cm-panels .cm-textfield:focus":{borderColor:"color-mix(in srgb, var(--cmux-editor-accent, currentColor) 60%, var(--cmux-editor-border, transparent))"},".cm-panels .cm-textfield::placeholder":{color:"var(--cmux-editor-muted, inherit)"},".cm-panels .cm-button":{backgroundImage:"none",backgroundColor:"transparent",border:"none",borderRadius:"5px",padding:"3px 10px",color:"var(--cmux-editor-fg, inherit)",font:"inherit"},".cm-panels .cm-button:hover":{backgroundColor:"color-mix(in srgb, var(--cmux-editor-fg, currentColor) 8%, transparent)"},".cm-panels .cm-button:active":{backgroundImage:"none",backgroundColor:"color-mix(in srgb, var(--cmux-editor-fg, currentColor) 14%, transparent)"},".cm-panels .cm-button:focus-visible, .cm-panels input[type=checkbox]:focus-visible":{outline:"2px solid color-mix(in srgb, var(--cmux-editor-fg, currentColor) 36%, transparent)",outlineOffset:"1px"},".cm-panel.cm-search label":{color:"var(--cmux-editor-muted, inherit)",fontSize:"inherit"},".cm-panel.cm-search input[type=checkbox]":{accentColor:"var(--cmux-editor-accent, auto)"},".cm-panel.cm-search button[name=close]":{color:"var(--cmux-editor-muted, inherit)",fontSize:"14px",width:"20px",height:"20px",lineHeight:"20px",borderRadius:"5px",top:"4px",right:"6px"},".cm-panel.cm-search button[name=close]:hover":{color:"var(--cmux-editor-fg, inherit)",backgroundColor:"color-mix(in srgb, var(--cmux-editor-fg, currentColor) 8%, transparent)"}});function S(r){const e=document.documentElement.style,t=M(r.terminal)?r.terminal:null;e.setProperty("--cmux-editor-bg",t?"transparent":r.pageBackground),e.setProperty("--cmux-editor-fg",t?t.foreground:r.text),e.setProperty("--cmux-editor-muted",r.mutedText),e.setProperty("--cmux-editor-accent",r.accent),e.setProperty("--cmux-editor-accent-soft",r.accentSoft),e.setProperty("--cmux-editor-border",r.border),e.setProperty("--cmux-editor-surface",r.surfaceBackground),e.setProperty("--cmux-editor-panel",r.surfaceElevatedBackground),e.setProperty("--cmux-editor-input",r.inputBackground),e.setProperty("--cmux-editor-danger",r.danger),f(e,"--cmux-editor-caret",t?.cursorColor||null),f(e,"--cmux-editor-selection",t?.selectionBackground||null),f(e,"--cmux-editor-font-family",t?.fontFamily?`"${t.fontFamily.replace(/"/g,'\\"')}", ui-monospace, 'SF Mono', Menlo, monospace`:null),f(e,"--cmux-editor-font-size",t?.fontSize&&t.fontSize>0?`${t.fontSize}px`:null),e.setProperty("color-scheme",r.isDark?"dark":"light")}function f(r,e,t){t?r.setProperty(e,t):r.removeProperty(e)}function E(r){const e=M(r.terminal)?se(r.terminal):r.isDark?re:te;return[ue,oe(e,{fallback:!0})]}const me={Find:"検索",Replace:"置換",next:"次へ",previous:"前へ",all:"すべて","match case":"大文字と小文字を区別","by word":"単語単位",regexp:"正規表現",replace:"置換","replace all":"すべて置換",close:"閉じる","current match":"現在の一致","replaced $ matches":"$ 件置換しました","replaced match on line $":"$ 行目の一致を置換しました","on line":"行","Go to line":"行へ移動",go:"移動","Folded lines":"折りたたまれた行",unfold:"展開","Fold line":"行を折りたたむ","Unfold line":"行を展開","Control character":"制御文字","Selection deleted":"選択範囲を削除しました"};function pe(r){return r.toLowerCase().startsWith("ja")?[B.phrases.of(me)]:[]}function N(r){return r?[x.lineWrapping]:[]}function ge(r,e,t){const a=document.createElement("div");a.className="cmux-editor-banner";const l=document.createElement("span");l.className="cmux-editor-banner-message";const c=document.createElement("button");c.className="cmux-editor-banner-primary",c.textContent=r.reloadFromDisk,c.addEventListener("click",e);const u=document.createElement("button");return u.textContent=r.keepMyChanges,u.addEventListener("click",t),a.append(l,c,u),{element:a,show(m){const d=m==="conflict";l.textContent=d?r.fileChangedOnDisk:r.saveFailed,a.classList.toggle("cmux-editor-banner-error",!d),c.style.display=d?"":"none",u.style.display=d?"":"none",a.classList.add("cmux-editor-banner-visible")},hide(){a.classList.remove("cmux-editor-banner-visible")}}}async function fe(r){const e=await v("editor.ready");S(e.theme),ne("editor",de);const t=new ie(e.diskContent),a=new h,l=new h,c=new h;let u=t.isDirty(e.content),m=null,d=!1;const p=()=>{const n=t.isDirty(i.state.doc.toString());n!==u&&(u=n,v("editor.dirtyChanged",{isDirty:n}).catch(()=>{}))},P=()=>{m!==null&&clearTimeout(m),m=setTimeout(()=>{m=null,p()},le)},C=n=>{const g=i.state.selection.main.head;i.dispatch({changes:{from:0,to:i.state.doc.length,insert:n},selection:{anchor:Math.min(g,n.length)}})},L=async()=>{if(d)return;d=!0;const n=i.state.doc.toString();try{(await v("editor.save",{content:n})).saved?(t.noteSaved(n),s.hide()):s.show("error")}catch{s.show("error")}finally{d=!1,p()}},s=ge(e.copy,()=>{C(t.resolveConflictReload()),s.hide(),p(),i.focus()},()=>{t.resolveConflictKeepMine(),s.hide(),p(),i.focus()}),i=new x({state:B.create({doc:e.content,extensions:[K(),T(),H(),R(),W(),z(),I(),$(),G(),q(),O(),A(),U({top:!0}),V.of([{key:"Mod-s",run:()=>(L(),!0)},..._,...j,...Y,...Q,...Z,J]),a.of([]),l.of(E(e.theme)),c.of(N(e.wordWrap)),pe(e.locale??"en"),x.updateListener.of(n=>{n.docChanged&&P()})]})}),b=document.createElement("div");b.className="cmux-editor-container",b.append(i.dom),r.append(s.element,b),window.cmuxEditorHost={getContent:()=>i.state.doc.toString()},ae(n=>{switch(n.type){case"document.external":{const g=t.applyExternal(i.state.doc.toString(),n.content);g.kind==="replaceBuffer"?(C(g.content),s.hide()):g.kind==="showConflict"?s.show("conflict"):s.hide(),p();break}case"document.saved":{t.noteSaved(n.content),s.hide(),p();break}case"app.theme":{S(n.theme),i.dispatch({effects:l.reconfigure(E(n.theme))});break}case"app.options":{i.dispatch({effects:c.reconfigure(N(n.wordWrap))});break}}});const D=e.path.split("/").pop()??e.path,k=X.matchFilename(ee,D);k&&k.load().then(n=>{i.dispatch({effects:a.reconfigure(n)})}).catch(n=>{console.warn("cmux editor: language load failed",n)}),window.addEventListener("focus",()=>{i.focus()}),document.hasFocus()&&i.focus()}function ve(r){fe(r).catch(e=>{console.error("cmux editor: surface bootstrap failed",e)})}export{ve as mountEditorSurface};
