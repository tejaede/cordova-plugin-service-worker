BUNDLE=[["index.html.bundle-1-0.js"]],!function(e,t){"function"==typeof define&&define.amd?define("montage",[],t):"object"==typeof module&&module.exports?module.exports=t(require,exports,module):e.Montage=t({},{},{})}(this,function(e,t,n){"use strict";var r=eval,i=r("this");i.global=i;var o={makeResolve:function(){try{var e="http://example.org",t="/test.html",n=new URL(t,e).href;if(!n||n!==e+t)throw new Error("NotSupported");return function(e,t){return new URL(t,e).href}}catch(r){var i=/^[\w\-]+:/,o=document.querySelector("head"),a=o.querySelector("base"),s=document.createElement("base"),l=document.createElement("a"),u=!1;return a?u=!0:a=document.createElement("base"),s.href="",function(e,t){var n;if(u||o.appendChild(a),e=String(e),i.test(e)===!1)throw new Error("Can't resolve from a relative location: "+JSON.stringify(e)+" "+JSON.stringify(t));u&&(n=a.href),a.href=e,l.href=t;var r=l.href;return u?a.href=n:o.removeChild(a),r}}},load:function(e,t){var n=document.createElement("script");n.src=e,n.onload=function(){t&&t(n),n.parentNode.removeChild(n)},document.getElementsByTagName("head")[0].appendChild(n)},getParams:function(){var e,t,n,r,i,o,a;if(!this._params){this._params={};var s=document.getElementsByTagName("script");for(e=0;e<s.length;e++)if(r=s[e],i=!1,r.src&&(n=r.src.match(/^(.*)montage.js(?:[\?\.]|$)/i))&&(this._params.montageLocation=n[1],i=!0),r.hasAttribute("data-montage-location")&&(this._params.montageLocation=r.getAttribute("data-montage-location"),i=!0),i){if(r.dataset)for(a in r.dataset)r.dataset.hasOwnProperty(a)&&(this._params[a]=r.dataset[a]);else if(r.attributes){var l=/^data-(.*)$/,u=/-([a-z])/g,c=function(e,t){return t.toUpperCase()};for(t=0;t<r.attributes.length;t++)o=r.attributes[t],n=o.name.match(l),n&&(this._params[n[1].replace(u,c)]=o.value)}r.parentNode.removeChild(r);break}}return this._params},bootstrap:function(e){function t(){l&&s&&e(s,u,c)}function n(){document.removeEventListener("DOMContentLoaded",n,!0),l=!0;var e=document.documentElement;e.classList?e.classList.add("montage-app-bootstrapping"):e.className=e.className+" montage-app-bootstrapping",document._montageTiming=document._montageTiming||{},document._montageTiming.bootstrappingStartTime=Date.now(),t()}function r(e){if(!v[e]&&f[e]){var t=v[e]={};v[e]=f[e](r,t)||t}return v[e]}function a(){c=r("mini-url"),u=r("promise"),s=r("require"),delete i.bootstrap,t()}var s,l,u,c,h=this.getParams(),p=this.makeResolve();/interactive|complete/.test(document.readyState)?n():document.addEventListener("DOMContentLoaded",n,!0);var d={require:"node_modules/mr/require.js","require/browser":"node_modules/mr/browser.js",promise:"node_modules/bluebird/js/browser/bluebird.min.js"},f={},v={};if(i.bootstrap=function(e,t){f[e]=t,delete d[e];for(var n in d)if(d.hasOwnProperty(n))return;a()},"undefined"==typeof i.BUNDLE){var m=p(i.location,h.montageLocation);o.load(p(m,d.promise),function(){delete d.promise,i.bootstrap("bluebird",function(e,t){return i.Promise}),i.bootstrap("promise",function(e,t){return i.Promise});for(var e in d)d.hasOwnProperty(e)&&o.load(p(m,d[e]))})}else i.nativePromise=i.Promise,Object.defineProperty(i,"Promise",{configurable:!0,set:function(e){Object.defineProperty(i,"Promise",{value:e}),i.bootstrap("bluebird",function(e,t){return i.Promise}),i.bootstrap("promise",function(e,t){return i.Promise})}});i.bootstrap("mini-url",function(e,t){t.resolve=p})},initMontage:function(e,n,r){for(var o,a=["core/core","core/event/event-manager","core/serialization/deserializer/montage-reviver","core/logger"],s=e("core/promise").Promise,l=[],u=0;o=a[u];u++)l.push(e.deepLoad(o));return s.all(l).then(function(){for(var o,s=0;o=a[s];s++)e(o);var l,u=(e("core/core").Montage,e("core/event/event-manager").EventManager,e("core/event/event-manager").defaultEventManager),c=e("core/serialization/deserializer/montage-deserializer").MontageDeserializer,h=e("core/serialization/deserializer/montage-reviver").MontageReviver;e("core/logger").logger,t.MontageDeserializer=c,t.Require.delegate=t,"function"==typeof i.montageWillLoad&&i.montageWillLoad();var p,d,f=n.packageDescription.applicationPrototype;return f?(p=h.parseObjectLocationId(f),d=n.async(p.moduleId)):d=e.async("core/application"),d.then(function(e){var t=e[p?p.objectName:"Application"];return l=new t,u.application=l,l.eventManager=u,l._load(n,function(){r.module&&n.async(r.module),"function"==typeof i.montageDidLoad&&i.montageDidLoad(),window.MontageElement&&MontageElement.ready(n,l,h)})})})}};return t.compileMJSONFile=function(e,n,r){var i=new t.MontageDeserializer;return i.init(e,n,void 0,n.location+r),i.deserializeObject()},t.initMontageCustomElement=function(){function e(e){var t=function(){return Reflect.construct(HTMLElement,[],t)};return Object.setPrototypeOf(t.prototype,(e||HTMLElement).prototype),Object.setPrototypeOf(t,e||HTMLElement),t}function t(t,r){if(!customElements.get(t)){var i=e(n);i.componentConstructor=r.constructor,i.observedAttributes=r.observedAttributes,customElements.define(t,i)}}if("undefined"!=typeof window.customElements&&"undefined"!=typeof window.Reflect){var n=e();n.pendingCustomElements=new Map,n.define=function(e,n,r){r&&"object"==typeof r?r.constructor=n:r={constructor:n},this.require?t(e,r):this.pendingCustomElements.set(e,r)},n.ready=function(e,r,i){n.prototype.findProxyForElement=i.findProxyForElement,this.application=r,this.require=e,this.pendingCustomElements.forEach(function(e,n){t(n,e)}),this.pendingCustomElements.clear()},Object.defineProperties(n.prototype,{require:{get:function(){return n.require},configurable:!1},application:{get:function(){return n.application},configurable:!1},componentConstructor:{get:function(){return this.constructor.componentConstructor},configurable:!1},observedAttributes:{get:function(){return this.constructor.observedAttributes},configurable:!1}}),n.prototype.connectedCallback=function(){if(!this._instance){var e=this,t=this.instantiateComponent();return this.findParentComponent().then(function(n){e._instance=t,n.addChildComponent(t),t._canDrawOutsideDocument=!0,t.needsDraw=!0})}},n.prototype.disconnectedCallback=function(){},n.prototype.findParentComponent=function(){for(var e,t,n=this.application.eventManager,r=this;null!==(e=r.parentNode)&&!(t=n.eventHandlerForElement(e));)r=e;return Promise.resolve(t)||this.getRootComponent()},n.prototype.getRootComponent=function(){return n.rootComponentPromise||(n.rootComponentPromise=this.require.async("montage/ui/component").then(function(e){return e.__root__})),n.rootComponentPromise},n.prototype.instantiateComponent=function(){var e=new this.componentConstructor;return this.bootstrapComponent(e),e.element=document.createElement("div"),e},n.prototype.bootstrapComponent=function(e){var t=this.attachShadow({mode:"open"}),n=e.enterDocument,r=e.templateDidLoad,i=this.findProxyForElement(this);if(i){var o,a,s=this.observedAttributes,l=this;if(s&&(a=s.length))for(var u=0;u<a;u++)o=s[u],e.defineBinding(o,{"<->":""+o,source:i})}this.application.eventManager.registerTargetForActivation(t),e.templateDidLoad=function(){var n=e.getResources();n&&(l.injectResourcesWithinCustomElement(n.styles,t),l.injectResourcesWithinCustomElement(n.scripts,t)),this.templateDidLoad=r,"function"==typeof this.templateDidLoad&&this.templateDidLoad()},e.enterDocument=function(e){t.appendChild(this.element),this.enterDocument=n,"function"==typeof this.enterDocument&&this.enterDocument(e)}},n.prototype.injectResourcesWithinCustomElement=function(e,t){if(e&&e.length)for(var n=0,r=e.length;n<r;n++)t.appendChild(e[n])},i.MontageElement=n}},t.initMontage=function(){var e=t.getPlatform();e.bootstrap(function(n,r,o){var a=e.getParams(),s={location:n.getLocation()};t.Require=n;var l=o.resolve(s.location,a.montageLocation),u=o.resolve(s.location,a["package"]||"."),c=a.applicationHash;if("object"==typeof i.BUNDLE){var h={},p=function(e){if(!h[e]){var t=h[e]={},n=new r(function(e,n){t.resolve=e,t.reject=n});return t.promise=n,t}return h[e]};i.bundleLoaded=function(e){p(e).resolve()};var d={},f=new r(function(e,t){d.resolve=e,d.reject=t});d.promise=f,s.preloaded=d.promise;var v=r.resolve();i.BUNDLE.forEach(function(t){v=v.then(function(){return r.all(t.map(function(t){return e.load(t),p(t).promise}))})}),d.resolve(v.then(function(){delete i.BUNDLE,delete i.bundleLoaded}))}var m;if("remoteTrigger"in a){window.postMessage({type:"montageReady"},"*");var g=new r(function(e){var t=function(n){if(a.remoteTrigger===n.origin&&(n.source===window||n.source===window.parent))switch(n.data.type){case"montageInit":window.removeEventListener("message",t),e([n.data.location,n.data.injections]);break;case"isMontageReady":window.postMessage({type:"montageReady"},"*")}};window.addEventListener("message",t)});m=g.spread(function(e,t){var r=n.loadPackage({location:e,hash:c},s);return t&&(r=r.then(function(n){e=o.resolve(e,".");var r,i,a=t.packageDescriptions,s=t.packageDescriptionLocations,l=t.mappings,u=t.dependencies;if(a)for(i=a.length,r=0;r<i;r++)n.injectPackageDescription(a[r].location,a[r].description);if(s)for(i=s.length,r=0;r<i;r++)n.injectPackageDescriptionLocation(s[r].location,s[r].descriptionLocation);if(l)for(i=l.length,r=0;r<i;r++)n.injectMapping(l[r].dependency,l[r].name);if(u)for(i=u.length,r=0;r<i;r++)n.injectDependency(u[r].name,u[r].version);return n})),r})}else{if("autoPackage"in a)n.injectPackageDescription(u,{dependencies:{montage:"*"}},s);else if(".json"===u.slice(u.length-5)){var _=u;u=o.resolve(u,"."),n.injectPackageDescriptionLocation(u,_,s)}m=n.loadPackage({location:u,hash:c},s)}return m.then(function(t){return t.loadPackage({location:l,hash:a.montageHash}).then(function(e){var t;t=a.promiseLocation?o.resolve(n.getLocation(),a.promiseLocation):o.resolve(l,"node_modules/bluebird");var r=[e,e.loadPackage({location:t,hash:a.promiseHash})];return r}).spread(function(n,l){return n.inject("core/mini-url",o),n.inject("core/promise",{Promise:r}),l.inject("bluebird",r),l.inject("js/browser/bluebird",r),s.lint=function(e){n.async("core/jshint").then(function(t){t.JSHINT(e.text)||(console.warn("JSHint Error: "+e.location),t.JSHINT.errors.forEach(function(e){e&&(console.warn("Problem at line "+e.line+" character "+e.character+": "+e.reason),e.evidence&&console.warn("    "+e.evidence))}))})},i.require=i.mr=t,e.initMontage(n,t,a)})}).done()})},t.getPlatform=function(){if("undefined"!=typeof self&&"undefined"!=typeof importScripts)return importScripts("packages/montage@4893e99/worker.js"),worker;if("undefined"!=typeof window&&window&&window.document)return o;if("undefined"!=typeof process)return e("./node.js");throw new Error("Platform not supported.")},"undefined"!=typeof self&&"undefined"!=typeof importScripts?t.initMontage():"undefined"!=typeof window?i.__MONTAGE_LOADED__?console.warn("Montage already loaded!"):(i.__MONTAGE_LOADED__=!0,t.initMontage(),t.initMontageCustomElement()):t.getPlatform(),t}),!function(e){if("undefined"!=typeof bootstrap)"undefined"!=typeof self&&"undefined"!=typeof importScripts?bootstrap("require",function(t,n){var r=t("promise").Promise,i=t("mini-url");e(n,r,i),t("require/worker")}):"undefined"!=typeof window&&bootstrap("require",function(t,n){var r=t("promise"),i=t("mini-url");e(n,r,i),t("require/browser")});else{if("undefined"==typeof process)throw new Error("Can't support require on this platform");var t=require("bluebird"),n=require("url");e(exports,t,n),require("./node")}}(function(e,t,n){"use strict";function r(e){var t;return g.has(e)?t=g.get(e):(t=m.exec(e),t=t?t[1]:e,g.set(e,t)),t}function i(e,t){function n(n,r){var i;return t.has(n)?i=t.get(n):(i=e(n,r),t.set(n,i)),i}return n}function o(e,t,n){var r=e.length,i=String(t),o=i.length,a=r;void 0!==n&&(a=n?Number(n):0,a!==a&&(a=0));var s=Math.min(Math.max(a,0),r),l=s-o;if(l<0)return!1;for(var u=-1;++u<o;)if(e.charCodeAt(l+u)!==i.charCodeAt(u))return!1;return!0}function a(e,t,n){""===t||"."===t||(".."===t?n.length&&n.pop():n.push(t))}function s(e,t){if(""===e&&""===t)return"";var n,r,i=_.get(e)||_.set(e,i=new p)&&i||i;if(!(i.has(t)&&e in i.get(t))){e=String(e);var o=y.get(e)||y.set(e,o=e.split("/"))&&o||o,s=y.get(t)||y.set(t,s=t.split("/"))&&s||s,l=a;if(o.length&&"."===o[0]||".."===o[0])for(n=0,r=s.length-1;n<r;n++)l(s,s[n],b);for(n=0,r=o.length;n<r;n++)l(o,o[n],b);i.get(t)||i.set(t,new p),i.get(t).set(e,b.join("/")),b.length=0}return i.get(t).get(e)}function l(t,r,i){if(r=r||{},"string"==typeof t&&(t={location:t}),t.main&&(t.location=r.mainPackageLocation),t.name&&r.registry&&r.registry.has(t.name)&&(t.location=r.registry.get(t.name)),!t.location&&r.packagesDirectory&&t.name)t.location=n.resolve(r.packagesDirectory,t.name+"/");else if(!t.location)return t;if(w.test(t.location)||(t.location+="/"),!e.isAbsolute(t.location)){if(!r.location)throw new Error("Dependency locations must be fully qualified: "+JSON.stringify(t));t.location=n.resolve(r.location,t.location)}return t.name&&r.registry.set(t.name,t.location),t}function u(e,t){if(e)for(var n,r=0,i=Object.keys(e);n=i[r];r++)t[n]||(t[n]={name:n,version:e[n]})}function c(e){return e._args||e._requested?"flat":"nested"}function h(t,i,o){w.test(t)||(t+="/");var a=Object.create(o);a.name=i.name,a.location=t||e.getLocation(),a.packageDescription=i,a.useScriptInjection=i.useScriptInjection,a.strategy=o.strategy||c(i),void 0!==i.production&&(a.production=i.production);var h=a.modules=a.modules||{},p=a.registry;void 0===a.name||p.has(a.name)||p.set(a.name,a.location);var d,f=i.overlay||{};if("string"==typeof i.browser)f.browser={redirects:{"":i.browser}};else if("object"==typeof i.browser){var v,m,g=i.browser,_=Object.keys(g);for(f.browser={redirects:{}},d=f.browser.redirects,m=0;v=_[m];m++)g[v]!==!1&&(d[v]=g[v])}var y,b,O,j;b=a.overlays=a.overlays||e.overlays;for(var E=0,C=b.length;E<C;E++)if(y=f[O=b[E]])for(j in y)y.hasOwnProperty(j)&&(i[j]=y[j]);if(delete i.overlay,"flat"===a.strategy?a.packagesDirectory=n.resolve(a.mainPackageLocation,"node_modules/"):a.packagesDirectory=n.resolve(t,"node_modules/"),i.main=i.main||"index",h[""]={id:"",redirect:r(s(i.main,"")),location:a.location},d=i.redirects,void 0!==d)for(j in d)d.hasOwnProperty(j)&&(h[j]={id:j,redirect:r(s(d[j],j)),location:n.resolve(t,j)});var D=i.mappings||{};u(i.dependencies,D),a.production||u(i.devDependencies,D);for(var P=0,T=Object.keys(D);j=T[P];P++)D[j]=l(D[j],a,j);return a.mappings=D,a}var p,d=eval,f=d("this");f.Map?p=f.Map:(p=function(){this._content=Object.create(null)},p.prototype.constructor=p,p.prototype.set=function(e,t){return this._content[e]=t,this},p.prototype.get=function(e){return this.hasOwnProperty.call(this._content,e)?this._content[e]:null},p.prototype.has=function(e){return e in this._content});var v=function(){};v.prototype.id=null,v.prototype.display=null,v.prototype.require=null,v.prototype.factory=void 0,v.prototype.exports=void 0,v.prototype.redirect=void 0,v.prototype.location=null,v.prototype.directory=null,v.prototype.injected=!1,v.prototype.mappingRedirect=void 0,v.prototype.type=null,v.prototype.text=void 0,v.prototype.dependees=null,v.prototype.extraDependencies=void 0,v.prototype.uuid=null;var m=/^(.*)\.js$/,g=new p,_=new p,y=new p,b=[],w=/\/$/,O=/^[a-z]+$/;e.makeRequire=function(o){function a(e){var t=O.test(e)?e:e.toLowerCase();if(!(t in _)){var n=new v;_[t]=n,n.id=e,n.display=o.name||o.location,n.display+="#",n.display+=e,n.require=g}return _[t]}function u(e,t){var r,i,s=a(e),l=c(e);l?(r=o.mappings[l],e.length>l.length?(i=e.slice(l.length+1),s.location=n.resolve(r.location,i),"undefined"==typeof r.mappingRequire?o.loadPackage(r,o).then(function(e){r.mappingRequire=e,e.inject(i,t)}):r.mappingRequire.inject(i,t)):s.location=r.location):s.location=n.resolve(o.location,e),s.exports=t,s.directory=n.resolve(s.location,"./"),s.injected=!0,s.redirect=void 0,s.mappingRedirect=void 0,s.error=void 0}function c(e){var t,n,r=o.mappings,i=Object.keys(r),a=i.length;for(t=0;t<a;t++)if(n=i[t],e===n||0===e.indexOf(n)&&"/"===e.charAt(n.length))return n}function h(e,n,i){return i=i||Object.create(null),e in i?null:(i[e]=!0,y(e,n).then(function(){var n,o,l,u=a(e),c=u.dependencies;if(c&&c.length>0)for(var p=0;o=c[p];p++)(l=h(r(s(o,e)),e,i))&&(n?n.push?n.push(l):n=[n,l]:n=l);return n?void 0===n.push?n:t.all(n):null},function(t){a(e).error=t}))}function d(e,t){var r=a(e);if(r.id!==e)throw new Error("Can't require module "+JSON.stringify(r.id)+" by alternate spelling "+JSON.stringify(e));if(r.error){var i=new Error("Can't require module "+JSON.stringify(r.id)+" via "+JSON.stringify(t)+" because "+r.error.message);throw i.cause=r.error,i}if(void 0!==r.redirect)return d(r.redirect,t);if(void 0!==r.mappingRedirect)return r.mappingRequire(r.mappingRedirect,t);if(void 0!==r.exports)return r.exports;if(void 0===r.factory)throw new Error("Can't require module "+JSON.stringify(e)+" via "+JSON.stringify(t));r.directory=n.resolve(r.location,"./"),r.exports={};var s;try{s=o.executeCompiler(r.factory,m(e),r.exports,r)}catch(l){throw r.exports=void 0,l}return void 0!==s&&(r.exports=s),r.exports}function f(e,t,n){var r=o.location;if(t.location===r)return e;var i=!!n;if(n=n||new p,n.has(r))return null;n.set(r,!0);for(var a in o.mappings){var s=o.mappings[a];if(r=s.location,o.hasPackage(r)){var l=o.getPackage(r),u=l.identify(e,t,n);if(null!==u)return""===u?a:(a+="/",a+=u)}}if(i)return null;throw new Error("Can't identify "+e+" from "+t.location)}function m(t){var n=function(e){var n=r(s(e,t));return d(n,t)};n.viaId=t,n.async=function(e){var i=r(s(e,t));return h(i,t).then(function(){return n(i)})},n.resolve=function(e){return r(s(e,t))},n.getModule=a,n.getModuleDescriptor=a,n.load=y,n.deepLoad=h,n.loadPackage=function(t,n){return n?e.loadPackage(t,n):o.loadPackage(t,o)},n.hasPackage=function(e){return o.hasPackage(e)},n.getPackage=function(e){return o.getPackage(e)},n.isMainPackage=function(){return n.location===o.mainPackageLocation},n.injectPackageDescription=function(t,n){e.injectPackageDescription(t,n,o)},n.injectPackageDescriptionLocation=function(t,n){e.injectPackageDescriptionLocation(t,n,o)},n.injectMapping=function(e,t){e=l(e,o,t),t=t||e.name,o.mappings[t]=e},n.injectDependency=function(e){n.injectMapping({name:e},e)},n.identify=f,n.inject=u;for(var i=o.exposedConfigs,c=0,p=i.length;c<p;c++)n[i[c]]=o[i[c]];return n.config=o,n.read=o.read,n}var g;o=o||{},o.cache=o.cache||new p,o.rootLocation=n.resolve(o.rootLocation||e.getLocation(),"./"),o.location=n.resolve(o.location||o.rootLocation,"./"),o.paths=o.paths||[o.location],o.mappings=o.mappings||{},o.exposedConfigs=o.exposedConfigs||e.exposedConfigs,o.moduleTypes=o.moduleTypes||["html","meta","mjson"],o.makeLoader=o.makeLoader||e.makeLoader,o.load=o.load||o.makeLoader(o),o.makeCompiler=o.makeCompiler||e.makeCompiler,o.executeCompiler=o.executeCompiler||e.executeCompiler,o.compile=o.compile||o.makeCompiler(o),o.parseDependencies=o.parseDependencies||e.parseDependencies,o.read=o.read||e.read,o.strategy=o.strategy||"nested";var _=o.modules=o.modules||Object.create(null),y=i(function(e,n){var r=a(e);return t["try"](function(){if(void 0===r.factory&&void 0===r.exports&&void 0===r.redirect)return o.load(e,r)}).then(function(){return o.compile(r).then(function(){void 0!==r.redirect&&(r.dependencies=r.dependencies||[],r.dependencies.push(r.redirect)),void 0!==r.extraDependencies&&(r.dependencies=r.dependencies||[],Array.prototype.push.apply(r.dependencies,r.extraDependencies))})})},o.cache);return g=m("")},e.injectPackageDescription=function(e,n,r){var i=r.descriptions=r.descriptions||{};i[e]=t.resolve(n)},e.injectLoadedPackageDescription=function(t,n,r,i){var o,a=h(t,n,r);return"function"==typeof i?o=i:(e.delegate&&e.delegate.willCreatePackage&&(o=e.delegate.willCreatePackage(t,n,a)),o||(o=e.makeRequire(a),e.delegate&&e.delegate.didCreatePackage&&e.delegate.didCreatePackage(a))),r.packages[t]=o,o},e.injectPackageDescriptionLocation=function(e,t,n){var r=n.descriptionLocations=n.descriptionLocations||{};r[e]=t},e.loadPackageDescription=function(t,r){var i=t.location,o=r.descriptions=r.descriptions||{};if(void 0===o[i]){var a,s=r.descriptionLocations=r.descriptionLocations||{};a=s[i]?s[i]:n.resolve(i,"package.json");var l;e.delegate&&"function"==typeof e.delegate.requireWillLoadPackageDescriptionAtLocation&&(l=e.delegate.requireWillLoadPackageDescriptionAtLocation(a,t,r)),l||(l=(r.read||e.read)(a)),o[i]=l.then(function(e){try{return JSON.parse(e)}catch(t){throw t.message=t.message+" in "+JSON.stringify(a),t}})}return o[i]},e.loadPackage=function(t,n,r){if(t=l(t,n),!t.location)throw new Error("Can't find dependency: "+JSON.stringify(t));var i=t.location;n=Object.create(n||null);var o=n.loadingPackages=n.loadingPackages||{},a=n.packages={},s=n.registry=n.registry||new p;n.mainPackageLocation=n.mainPackageLocation||i,n.hasPackage=function(e){if(e=l(e,n),!e.location)return!1;var t=e.location;return!!a[t]},n.getPackage=function(e){if(e=l(e,n),!e.location)throw new Error("Can't find dependency: "+JSON.stringify(e)+" from "+n.location);var t=e.location;if(!a[t])throw o[t]?new Error("Dependency has not finished loading: "+JSON.stringify(e)):new Error("Dependency was not loaded: "+JSON.stringify(e));return a[t]},n.loadPackage=function(t,r){if(t=l(t,r),!t.location)throw new Error("Can't find dependency: "+JSON.stringify(t)+" from "+n.location);var i=t.location;return o[i]||(o[i]=e.loadPackageDescription(t,n).then(function(t){return e.injectLoadedPackageDescription(i,t,n)})),o[i]};var u;return u="object"==typeof r?e.injectLoadedPackageDescription(i,r,n):n.loadPackage(t),"function"==typeof u.then?u=u.then(function(e){return e.registry=s,e}):u.registry=s,u.location=i,u.async=function(e,t){return u.then(function(n){return n.async(e,t)})},u},e.resolve=s;var j=/\.([^\/\.]+)$/;e.extension=function(e){var t=j.exec(e);if(t)return t[1]};var E=/^[\w\-]+:/;e.isAbsolute=function(e){return E.test(e)};var C=/(?:^|[^\w\$_.])require\s*\(\s*["']([^"']*)["']\s*\)/g,D=/\/\/(.*)$/gm,P=/\/\*([\s\S]*?)\*\//g;e.parseDependencies=function(e){e=e.replace(D,"").replace(P,"");for(var t,n=[];null!==(t=C.exec(e));)n.push(t[1]);return n},e.DependenciesCompiler=function(t,n){return function(r){return r.dependencies||void 0===r.text||(r.dependencies=t.parseDependencies(r.text)),n(r),r&&!r.dependencies&&(r.text||r.factory?r.dependencies=e.parseDependencies(r.text||r.factory):r.dependencies=[]),r}};var T=/^#!/,A="//#!";e.ShebangCompiler=function(e,t){return function(e){e.text&&(e.text=e.text.replace(T,A)),t(e)}},e.LintCompiler=function(e,n){return function(r){try{n(r)}catch(i){throw i.message=i.message+" in "+r.location,console.log(i),e.lint&&t.resolve().then(function(){e.lint(r)}),i}}},e.exposedConfigs=["paths","mappings","location","packageDescription","packages","modules"];var x;x="undefined"!=typeof window||"undefined"!=typeof importScripts?function(t){return e.SerializationCompiler(t,e.TemplateCompiler(t,e.JsonCompiler(t,e.DependenciesCompiler(t,e.LintCompiler(t,e.Compiler(t))))))}:function(t){return e.SerializationCompiler(t,e.TemplateCompiler(t,e.JsonCompiler(t,e.ShebangCompiler(t,e.DependenciesCompiler(t,e.LintCompiler(t,e.Compiler(t)))))))},e.makeCompiler=function(n){return function(r){return new t(function(t,i){return e.MetaCompiler(r).then(function(){t("object"==typeof r.exports?r:x(n)(r))})})}},e.JsonCompiler=function(e,t){var n=/\.json$/;return function(e){var r=(e.location||"").match(n);if(r)return"object"!=typeof e.exports&&"string"==typeof e.text&&(e.exports=JSON.parse(e.text)),e;var i=t(e);return i}};var k=".mjson",S=".mjson.load.js";e.MetaCompiler=function(n){if(n.location&&(o(n.location,".meta")||o(n.location,k)||o(n.location,S))){if(e.delegate&&"function"==typeof e.delegate.compileMJSONFile)return e.delegate.compileMJSONFile(n.text||n.exports,n.require,n.id).then(function(e){if("string"==typeof n.text&&(n.exports=JSON.parse(n.text)),n.exports.montageObject)throw new Error("using reserved word as property name, 'montageObject' at: "+n.location);return Object.defineProperty(n.exports,"montageObject",{value:e,enumerable:!1,configurable:!0,writable:!0}),n});n.exports=n.text?JSON.parse(n.text):n.exports}return t.resolve(n)};var L=/(.*\/)?(?=[^\/]+)/,M=".html",R=".html.load.js";e.TemplateCompiler=function(e,t){return function(e){var n=e.location;if(n){if(o(n,M)||o(n,R)){var r=n.match(L);if(r)return e.dependencies=e.dependencies||[],e.exports={directory:r[1],content:e.text},e}t(e)}}};var F=function(e,t,n){return this.require=e,this.module=t,this.property=n,this};F.prototype={get moduleId(){return this.module},get objectName(){return this.property},get aliases(){return this._aliases||(this._aliases=[this.property])},_aliases:null,isInstance:!1};var z="_montage_metadata",I=/((.*)\.reel)\/\2$/,N=function(e,t){return t};e.executeCompiler=function(e,t,r,i){var o;return i.directory=n.resolve(i.location,"./"),i.filename=n.resolve(i.location,i.location),i.exports=r||{},o=e.call(f,t,r,i,f,i.filename,i.directory)},e.SerializationCompiler=function(e,t){return function(n){if(t(n),n.factory){var r=n.factory;return n.factory=function(t,n,i){var o;try{o=e.executeCompiler(r,t,n,i)}catch(a){if(!(a instanceof SyntaxError))throw a;e.lint(i)}if(o)return o;var s,l,u,c=Object.keys(n);for(s=0,u;u=c[s];s++)(l=n[u])instanceof Object&&(l.hasOwnProperty(z)&&!l[z].isInstance?l[z].aliases.push(u):Object.isSealed(l)||(l[z]=new F(t,i.id.replace(I,N),u)))},n}}},e.MappingsLoader=function(t,n){return t.mappings=t.mappings||{},t.name=t.name,function(r,i){function o(e){var n=r.slice(c.length+1);return t.mappings[c].mappingRequire=e,i.mappingRedirect=n,i.mappingRequire=e,e.deepLoad(n,t.location)}if(e.isAbsolute(r))return n(r,i);var a=t.mappings,s=Object.keys(a),l=s.length;void 0!==t.name&&0===r.indexOf(t.name)&&"/"===r.charAt(t.name.length)&&console.warn("Package reflexive module ignored:",r);var u,c;for(u=0;u<l;u++)if(c=s[u],r===c||0===r.indexOf(c)&&"/"===r.charAt(c.length))return t.loadPackage(a[c],t).then(o);return n(r,i)}},e.LocationLoader=function(t,r){function i(t,o){var a,s,l=t,u=i.config,c=e.extension(t);return(!c||"js"!==c&&"json"!==c&&u.moduleTypes.indexOf(c)===-1)&&(l+=".js"),a=o.location=n.resolve(u.location,l),u.delegate&&u.delegate.packageWillLoadModuleAtLocation&&(s=u.delegate.packageWillLoadModuleAtLocation(o,a)),s?s:r(a,o)}return i.config=t,i},e.MemoizedLoader=function(e,t){return i(t,e.cache)};var B=/([^\/]+)\.reel$/,W=".reel",V="/";e.ReelLoader=function(e,t){return function(e,n){return o(e,W)?(n.redirect=e,n.redirect+=V,n.redirect+=B.exec(e)[1],n):t(e,n)}}}),bootstrap("require/browser",function(e){function t(e){var n=e.target,r=n.module;200===n.status||0===n.status&&n.responseText?(r&&(r.type=c,r.text=n.responseText,r.location=n.url),n.resolve(n.responseText),t.xhrPool.push(n)):n.onerror(e)}function n(e){var t=e.target,r=t.url;r.indexOf(f)===r.length-3&&r.indexOf(d)!==r.length-9?(t.url=t.url.replace(f,d),t.module.location=t.url,t.open(l,t.url,!0),t.send(null)):(t.reject(new Error("Can't XHR "+JSON.stringify(r))),n.xhrPool.push(t),t.abort(),t.url=null,t.module=null)}function r(e,t){var n=r.xhrPool.pop();n||(n=new r.XMLHttpRequest,n.overrideMimeType&&n.overrideMimeType(u),n.onload=r.onload,n.onerror=r.onerror,n.promiseHandler=function(e,t){n.resolve=e,n.reject=t}),n.url=e,n.module=t,n.open(l,e,!0);var i=new a(n.promiseHandler);return n.send(null),i}var i,o=e("require"),a=e("promise"),s=e("mini-url"),l="GET",u="application/javascript",c="javascript",h=eval;h("this"),o.getLocation=function(){if(!i){var e=document.querySelector("head > base");i=e?e.href:window.location,i=s.resolve(i,".")}return i},o.overlays=["window","browser","montage"];var p=[];t.xhrPool=p;var d="/index.js",f=".js";n.xhrPool=p,o.read=r,r.xhrPool=p,r.XMLHttpRequest=XMLHttpRequest,r.onload=t,r.onerror=n;var v="__",m="_",g="(function ",_="(require, exports, module, global) {",y="//*/\n})\n//# sourceURL=",b=[g,void 0,_,void 0,y,void 0],w=/[^\w\d]/g;o.Compiler=function(e){return function(t){if(t.factory||void 0===t.text)return t;if(e.useScriptInjection)throw new Error("Can't use eval.");var n=[v,t.require.config.name,m,t.id].join("").replace(w,m);b[1]=n,b[3]=t.text,b[5]=t.location,t.factory=h(b.join("")),t.factory.displayName=n,t.text=null,b[1]=b[3]=b[5]=null}},o.XhrLoader=function(e){return function(t,n){return e.read(t,n).then(function(e){n.type=c,n.text=e,n.location=t})}};var O={},j=function(e,t){var n=O[e]=O[e]||{};if(!n[t]){var r;n[t]=new a(function(e,t){r=e}),n[t].resolve=r}return n[t]},E=function(e,t,n){var r=o.delegate&&o.delegate.loadScript||o.loadScript;n&&n.isPending()?n.then(function(){t.isPending()&&r(e)}):t.isPending()&&r(e)};montageDefine=function(e,t,n){j(e,t).resolve(n)},o.loadScript=function(e){var t=document.createElement("script");t.onload=function(){t.parentNode.removeChild(t)},t.onerror=function(e){t.parentNode.removeChild(t)},t.src=e,t.defer=!0,document.getElementsByTagName("head")[0].appendChild(t)},o.ScriptLoader=function(e){var t=e.packageDescription.hash;return function(n,r){return a["try"](function(){if(O[t]&&O[t][r.id])return O[t][r.id];/\.js$/.test(n)?n=n.replace(/\.js$/,".load.js"):n+=".load.js";var i=j(t,r.id);return E(n,i,e.preloaded),i}).then(function(e){delete O[t][r.id];for(var i in e)r[i]=e[i];r.location=n,r.directory=s.resolve(n,".")})}};var C=o.loadPackageDescription;o.loadPackageDescription=function(e,t){if(e.hash){var n=j(e.hash,"package.json"),r=s.resolve(e.location,"package.json.load.js");return E(r,n,t.preloaded),n.get("exports")}return C(e,t)},o.makeLoader=function(e){var t;return t=e.useScriptInjection?o.ScriptLoader:o.XhrLoader,o.ReelLoader(e,o.MappingsLoader(e,o.LocationLoader(e,o.MemoizedLoader(e,t(e)))))}}),bootstrap("require/worker",function(e){function t(e){return e.indexOf(d)===e.length-3&&e.indexOf(p)!==e.length-9}function n(e,n){var r,i=e.url;t(i)?(i=i.replace(d,p),n.location=i,r=new Request(i),r.promiseHandler=e.promiseHandler,o(r,n)):e.promiseHandler.reject(new Error("Can't fetch "+i))}function r(e,t,r){var i=e.url;null===t?n(e,r):r?(r.type=c,r.text=t,r.location=i,e.promiseHandler.resolve(t)):e.promiseHandler.resolve(t)}function i(e,t){var n=new Request(e);return new l(function(e,r){n.promiseHandler={reject:r,resolve:e},o(n,t)})}function o(e,t){return a(e).then(function(n){r(e,n,t)})["catch"](function(r){n(e,t)})}function a(e){return self.fetch(e).then(function(e){var t=e.status,n=0===t||200===t,r=200===t;return n?e.text().then(function(e){return r?e:e?e:null}):null})}var s=e("require"),l=e("promise"),u=e("mini-url"),c="javascript",h=eval;h("this"),s.overlays=["browser","montage"];var p="/index.js",d=".js";s.read=i;var f="__",v="_",m="(function ",g="(require, exports, module, global) {",_="//*/\n})\n//# sourceURL=",y=[m,void 0,g,void 0,_,void 0],b=/[^\w\d]/g;s.Compiler=function(e){return function(e){if(e.factory||void 0===e.text)return e;var t=[f,e.require.config.name,v,e.id].join("").replace(b,v);y[1]=t,y[3]=e.text,y[5]=e.location,e.factory=h(y.join("")),e.factory.displayName=t,e.text=null,y[1]=y[3]=y[5]=null}},s.FetchLoader=function(e){return function(t,n){return e.read(t,n).then(function(e){n.type=c,n.text=e,n.location=t})}},s.CachedFetchLoader=function(e){var t=e.packageDescription.hash;return function(n,r){return l["try"](function(){if(w[t]&&w[t][r.id])return w[t][r.id];/\.js$/.test(n)?n=n.replace(/\.js$/,".load.js"):n+=".load.js";var i=O(t,r.id);return j(n,i,e.preloaded),e.read(n,r).then(function(){return i})}).then(function(e){delete w[t][r.id];for(var i in e)r[i]=e[i];r.location=n,r.directory=u.resolve(n,".")})}};var w={},O=function(e,t){var n=w[e]=w[e]||{};if(!n[t]){var r;n[t]=new l(function(e,t){r=e}),n[t].resolve=r}return n[t]},j=function(e,t,n){var r=s.delegate&&s.delegate.loadScript||s.loadScript;n&&n.isPending()?n.then(function(){t.isPending()&&r(e)}):t.isPending()&&r(e)};self.montageDefine=function(e,t,n){O(e,t).resolve(n)},s.loadScript=function(e){a(e).then(function(e){h(e)})};var E=s.loadPackageDescription;s.loadPackageDescription=function(e,t){if(e.hash){var n=O(e.hash,"package.json"),r=u.resolve(e.location,"package.json.load.js");return j(r,n,t.preloaded),n.get("exports")}return E(e,t)},s.makeLoader=function(e){