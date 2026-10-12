#!/usr/bin/env python3
"""Generate deterministic, dependency-free Xcode app targets from shared sources."""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parent.parent
objects={}
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(key, body):
 i=uid(key); objects[i]=body; return i
def q(s): return json.dumps(str(s),ensure_ascii=False)
def seq(items): return '('+','.join(items)+',)' if items else '()'
def props(d): return '{'+''.join(f'{k} = {q(v)};' for k,v in d.items())+'}'
sources=sorted(root.glob('App/**/*.swift'))+sorted(root.glob('Sources/CoverCore/**/*.swift'))
resources=[p for p in sorted(root.glob('Sources/CoverCore/Resources/**/*')) if p.is_file() and p.suffix not in ['.txt','.md']]
refs={}
for p in sources+resources:
 rel=str(p.relative_to(root)); ext=p.suffix
 typ='sourcecode.swift' if ext=='.swift' else 'text.json' if ext=='.json' else 'file'
 refs[rel]=add('ref:'+rel, f'{{isa=PBXFileReference;lastKnownFileType={q(typ)};path={q(rel)};sourceTree="<group>";}}')
products=[]; targets=[]; cfgs=[]
for platform, name, sdk, supported in [('mac','BlogCoverMakerMac','macosx','macosx'),('ipad','BlogCoverMakerPad','iphoneos','iphoneos iphonesimulator')]:
 product=add('product:'+name, f'{{isa=PBXFileReference;explicitFileType=wrapper.application;includeInIndex=0;path={name}.app;sourceTree=BUILT_PRODUCTS_DIR;}}');products.append(product)
 phases=[]
 for kind,files in [('Sources',sources),('Resources',resources)]:
  bfs=[]
  for p in files:
   rel=str(p.relative_to(root)); bfs.append(add('build:'+name+':'+rel, f'{{isa=PBXBuildFile;fileRef={refs[rel]};}}'))
  phases.append(add(name+kind, f'{{isa=PBX{kind}BuildPhase;buildActionMask=2147483647;files={seq(bfs)};runOnlyForDeploymentPostprocessing=0;}}'))
 phases.append(add(name+'Frameworks','{isa=PBXFrameworksBuildPhase;buildActionMask=2147483647;files=();runOnlyForDeploymentPostprocessing=0;}'))
 configs=[]
 for config in ['Debug','Release']:
  settings={'PRODUCT_NAME':name,'PRODUCT_BUNDLE_IDENTIFIER':'com.seolin.blogcovermaker'+('.ipad' if platform=='ipad' else ''),'SWIFT_VERSION':'5.0','SDKROOT':sdk,'SUPPORTED_PLATFORMS':supported,'INFOPLIST_FILE':'App/Info.plist','GENERATE_INFOPLIST_FILE':'NO','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1','CODE_SIGN_STYLE':'Automatic','MACOSX_DEPLOYMENT_TARGET':'14.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','ENABLE_HARDENED_RUNTIME':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if config=='Debug' else '', 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS':'NO'}
  if platform=='ipad':settings.update({'TARGETED_DEVICE_FAMILY':'2','SUPPORTS_MACCATALYST':'NO','SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO'})
  configs.append(add(name+config,'{isa=XCBuildConfiguration;name='+config+';buildSettings='+props(settings)+';}'))
 cl=add(name+'configs','{isa=XCConfigurationList;buildConfigurations='+seq(configs)+';defaultConfigurationIsVisible=0;defaultConfigurationName=Release;}')
 tid=add(name,'{isa=PBXNativeTarget;buildConfigurationList='+cl+';buildPhases='+seq(phases)+';buildRules=();dependencies=();name='+name+';productName='+name+';productReference='+product+';productType="com.apple.product-type.application";}');targets.append(tid)
 # Explicit shared schemes, no signing/team assumption.
 scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tid}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:BlogCoverMakerBySeolin.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tid}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:BlogCoverMakerBySeolin.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
 sp=root/'BlogCoverMakerBySeolin.xcodeproj/xcshareddata/xcschemes'/f'{name}.xcscheme';sp.parent.mkdir(parents=True,exist_ok=True);sp.write_text(scheme)
pg=add('products','{isa=PBXGroup;children='+seq(products)+';name=Products;sourceTree="<group>";}')
main=add('group','{isa=PBXGroup;children='+seq(list(refs.values())+[pg])+';sourceTree="<group>";}')
for config in ['Debug','Release']:
 cfgs.append(add('project'+config,'{isa=XCBuildConfiguration;name='+config+';buildSettings={CLANG_ENABLE_MODULES=YES;};}'))
cl=add('projectconfigs','{isa=XCConfigurationList;buildConfigurations='+seq(cfgs)+';defaultConfigurationIsVisible=0;defaultConfigurationName=Release;}')
project=add('project','{isa=PBXProject;attributes={LastUpgradeCheck=2700;};buildConfigurationList='+cl+';compatibilityVersion="Xcode 14.0";developmentRegion=ko;hasScannedForEncodings=0;knownRegions=(en,ko,Base);mainGroup='+main+';productRefGroup='+pg+';projectDirPath="";projectRoot="";targets='+seq(targets)+';}')
(root/'BlogCoverMakerBySeolin.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion=1;classes={};objectVersion=56;objects={\n'+ '\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n};rootObject='+project+';}\n')
print(f'Generated macOS + iPadOS targets: {len(sources)} sources, {len(resources)} resources')
