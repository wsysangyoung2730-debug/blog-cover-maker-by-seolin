#!/usr/bin/env python3
"""Generate deterministic, dependency-free Xcode app targets from shared sources."""
from pathlib import Path
import hashlib, json, subprocess
root=Path(__file__).resolve().parent.parent
objects={}
# Keep local signing/version choices when regenerating source references.
project_path=root/'BlogCoverMakerBySeolin.xcodeproj/project.pbxproj'
previous_objects={}
if project_path.exists():
 previous_objects=json.loads(subprocess.check_output(
  ['plutil', '-convert', 'json', '-o', '-', str(project_path)]))['objects']
def previous_settings(key):
 return previous_objects.get(uid(key), {}).get('buildSettings', {})
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(key, body):
 i=uid(key); objects[i]=body; return i
def q(s): return json.dumps(str(s),ensure_ascii=False)
def seq(items): return '('+','.join(items)+',)' if items else '()'
def value(v):
 if isinstance(v, dict): return props(v)
 if isinstance(v, list): return seq([value(item) for item in v])
 return q(v)
def props(d): return '{'+''.join(f'{q(k)} = {value(v)};' for k,v in d.items())+'}'
sources=sorted(root.glob('App/**/*.swift'))+sorted(root.glob('Sources/CoverCore/**/*.swift'))
resources=[p for p in sorted(root.glob('Sources/CoverCore/Resources/**/*')) if p.is_file() and p.name != 'README.txt']
catalogs=sorted(root.glob('App/**/*.xcassets'))
resources+=catalogs
resources+=sorted(root.glob('App/Resources/*.xcprivacy'))
# Navigator references include supporting files, but only sources/resources
# above are added to app build phases. Test fixtures never enter the app bundle.
navigator_files=set(sources+resources)
for folder in ['App', 'Sources', 'Tests', 'Docs', 'Scripts', 'Reference', 'Design', '.github']:
 navigator_files.update(p for p in (root/folder).rglob('*')
  if p.is_file() and not any(parent in catalogs for parent in p.parents)
   and not any(part.startswith('.') or part == '__pycache__'
   for part in p.relative_to(root/folder).parts))
for name in ['README.md', 'AGENTS.md', 'Package.swift', '.gitignore']:
 if (root/name).exists(): navigator_files.add(root/name)
refs={}
for p in sorted(navigator_files):
 rel=str(p.relative_to(root)); ext=p.suffix
 typ={'.swift':'sourcecode.swift', '.json':'text.json', '.plist':'text.plist.xml', '.entitlements':'text.plist.entitlements', '.xcprivacy':'text.xml', '.md':'net.daringfireball.markdown', '.py':'text.script.python', '.mjs':'sourcecode.javascript', '.html':'text.html', '.png':'image.png', '.txt':'text', '.xcassets':'folder.assetcatalog'}.get(ext, 'file')
 refs[rel]=add('ref:'+rel, f'{{isa=PBXFileReference;lastKnownFileType={q(typ)};path={q(p.name)};sourceTree="<group>";}}')
products=[]; targets=[]; cfgs=[]
for platform, name, sdk, supported in [('mac','BlogCoverMakerMac','macosx','macosx'),('ipad','BlogCoverMakerPad','iphoneos','iphoneos iphonesimulator')]:
 product=add('product:'+name, f'{{isa=PBXFileReference;explicitFileType=wrapper.application;includeInIndex=0;path={name}.app;sourceTree=BUILT_PRODUCTS_DIR;}}');products.append(product)
 phases=[]
 platform_sources=[p for p in sources if not (root/'App/Platforms'/('iPadOS' if platform=='mac' else 'macOS')) in p.parents]
 for kind,files in [('Sources',platform_sources),('Resources',resources)]:
  bfs=[]
  for p in files:
   rel=str(p.relative_to(root)); bfs.append(add('build:'+name+':'+rel, f'{{isa=PBXBuildFile;fileRef={refs[rel]};}}'))
  phases.append(add(name+kind, f'{{isa=PBX{kind}BuildPhase;buildActionMask=2147483647;files={seq(bfs)};runOnlyForDeploymentPostprocessing=0;}}'))
 phases.append(add(name+'Frameworks','{isa=PBXFrameworksBuildPhase;buildActionMask=2147483647;files=();runOnlyForDeploymentPostprocessing=0;}'))
 configs=[]
 for config in ['Debug','Release']:
  settings={'PRODUCT_NAME':name,'PRODUCT_BUNDLE_IDENTIFIER':'com.seolin.blogcovermaker'+('.ipad' if platform=='ipad' else ''),'SWIFT_VERSION':'5.0','SDKROOT':sdk,'SUPPORTED_PLATFORMS':supported,'INFOPLIST_FILE':'App/Configuration/Info.plist','GENERATE_INFOPLIST_FILE':'NO','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1','CODE_SIGN_STYLE':'Automatic','MACOSX_DEPLOYMENT_TARGET':'14.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','ENABLE_HARDENED_RUNTIME':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if config=='Debug' else '', 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS':'NO'}
  if platform=='ipad':settings.update({'TARGETED_DEVICE_FAMILY':'2','SUPPORTS_MACCATALYST':'NO','SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO'})
  settings.update(previous_settings(name+config))
  settings['INFOPLIST_FILE']='App/Configuration/Info.plist'
  settings['DEBUG_INFORMATION_FORMAT']='dwarf' if config=='Debug' else 'dwarf-with-dsym'
  settings['ENABLE_TESTABILITY']='YES' if config=='Debug' else 'NO'
  settings['SKIP_INSTALL']='NO'
  if platform=='mac':
   settings['CODE_SIGN_ENTITLEMENTS']='App/Configuration/BlogCoverMakerMac.entitlements'
   settings['ENABLE_APP_SANDBOX']='YES'
   settings['ENABLE_USER_SELECTED_FILES']='readwrite'
  settings['ASSETCATALOG_COMPILER_APPICON_NAME']='AppIconMac' if platform=='mac' else 'AppIconPad'
  configs.append(add(name+config,'{isa=XCBuildConfiguration;name='+config+';buildSettings='+props(settings)+';}'))
 cl=add(name+'configs','{isa=XCConfigurationList;buildConfigurations='+seq(configs)+';defaultConfigurationIsVisible=0;defaultConfigurationName=Release;}')
 tid=add(name,'{isa=PBXNativeTarget;buildConfigurationList='+cl+';buildPhases='+seq(phases)+';buildRules=();dependencies=();name='+name+';productName='+name+';productReference='+product+';productType="com.apple.product-type.application";}');targets.append(tid)
 # Explicit shared schemes, no signing/team assumption.
 scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tid}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:BlogCoverMakerBySeolin.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tid}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:BlogCoverMakerBySeolin.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
 sp=root/'BlogCoverMakerBySeolin.xcodeproj/xcshareddata/xcschemes'/f'{name}.xcscheme';sp.parent.mkdir(parents=True,exist_ok=True);sp.write_text(scheme)
pg=add('products','{isa=PBXGroup;children='+seq(products)+';name=Products;sourceTree="<group>";}')
def directory_group(directory):
 # Every child uses its basename, resolved relative to its real parent folder.
 children=[]
 entries=[p for p in directory.iterdir() if any(
  file == p or p in file.parents for file in navigator_files)]
 for p in sorted(entries, key=lambda p: (not p.is_dir(), p.name.casefold())):
  children.append(directory_group(p) if p.is_dir() and p not in catalogs else refs[str(p.relative_to(root))])
 rel=str(directory.relative_to(root))
 return add('group:'+rel, '{isa=PBXGroup;children='+seq(children)+';path='+q(directory.name)+';sourceTree="<group>";}')
root_children=[directory_group(root/folder) for folder in ['App', 'Sources', 'Tests', 'Docs', 'Scripts', 'Reference', 'Design', '.github'] if (root/folder).exists()]
root_children.extend(refs[name] for name in ['README.md', 'AGENTS.md', 'Package.swift', '.gitignore'] if name in refs)
main=add('group','{isa=PBXGroup;children='+seq(root_children+[pg])+';sourceTree="<group>";}')
for config in ['Debug','Release']:
 settings={'CLANG_ENABLE_MODULES':'YES', **previous_settings('project'+config)}
 cfgs.append(add('project'+config,'{isa=XCBuildConfiguration;name='+config+';buildSettings='+props(settings)+';}'))
cl=add('projectconfigs','{isa=XCConfigurationList;buildConfigurations='+seq(cfgs)+';defaultConfigurationIsVisible=0;defaultConfigurationName=Release;}')
attributes={'LastUpgradeCheck':'2700', **previous_objects.get(uid('project'), {}).get('attributes', {})}
project=add('project','{isa=PBXProject;attributes='+props(attributes)+';buildConfigurationList='+cl+';compatibilityVersion="Xcode 14.0";developmentRegion=ko;hasScannedForEncodings=0;knownRegions=(en,ko,Base);mainGroup='+main+';productRefGroup='+pg+';projectDirPath="";projectRoot="";targets='+seq(targets)+';}')
(root/'BlogCoverMakerBySeolin.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion=1;classes={};objectVersion=56;objects={\n'+ '\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n};rootObject='+project+';}\n')
print(f'Generated macOS + iPadOS targets: {len(sources)} sources, {len(resources)} resources')
