#!/usr/bin/env python3
"""Inspect built app/archive metadata; Apple signing/upload validation remains separate."""
import argparse, json, plistlib, re, subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('app', type=Path)
parser.add_argument('--platform', choices=['mac', 'ipad'], required=True)
parser.add_argument('--signed', action='store_true', help='Also verify embedded macOS entitlements')
args = parser.parse_args()
app = args.app
bundle = app / 'Contents' if args.platform == 'mac' else app
resources = bundle / 'Resources' if args.platform == 'mac' else bundle
info = plistlib.loads((bundle / 'Info.plist').read_bytes())
privacy = plistlib.loads((resources / 'PrivacyInfo.xcprivacy').read_bytes())
assert info['CFBundlePackageType'] == 'APPL'
assert re.fullmatch(r'\d+\.\d+(\.\d+)?', info['CFBundleShortVersionString'])
assert info['CFBundleVersion'].isdigit()
assert info['ITSAppUsesNonExemptEncryption'] is False
assert info['NSHumanReadableCopyright'] == '© 2026 SEOLIN'
assert info['CFBundleDevelopmentRegion'] == 'ko'
assert privacy['NSPrivacyTracking'] is False
assert privacy['NSPrivacyCollectedDataTypes'] == []
assert privacy['NSPrivacyAccessedAPITypes'] == [{
 'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
 'NSPrivacyAccessedAPITypeReasons': ['CA92.1']}]
assert info['UTExportedTypeDeclarations'][0]['UTTypeIdentifier'] == 'com.seolin.cover-project'
assert info['CFBundleDocumentTypes'][0]['LSItemContentTypes'] == ['com.seolin.cover-project']
assert len(json.loads((resources / 'catalog.json').read_text())['templates']) == 50
assert (resources / 'font-manifest.json').exists()
assert len(list(resources.glob('*-OFL.txt'))) == 17
binary = (bundle / 'MacOS' if args.platform == 'mac' else bundle) / info['CFBundleExecutable']
assert b'--screenshot-fixture' not in binary.read_bytes(), '촬영 전용 진입점이 Release에 포함됨'
arches = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).split()
if args.platform == 'mac':
 assert set(arches) == {'arm64', 'x86_64'}, arches
 assert info['LSApplicationCategoryType'] == 'public.app-category.graphics-design'
 assert info['LSMinimumSystemVersion'] == '14.0'
 assert (resources / (info['CFBundleIconFile'] + '.icns')).exists()
 if args.signed:
  subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
  entitlements = plistlib.loads(subprocess.check_output(
   ['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL))
  assert entitlements.get('com.apple.security.app-sandbox') is True
  assert entitlements.get('com.apple.security.files.user-selected.read-write') is True
  assert not entitlements.get('com.apple.security.get-task-allow', False)
else:
 assert arches == ['arm64'], arches
 assert info['MinimumOSVersion'] == '17.0'
 assert info['UIDeviceFamily'] == [2]
 assert info['LSSupportsOpeningDocumentsInPlace'] is False
 assert info['UISupportsDocumentBrowser'] is False
 assert info['CFBundleIcons~ipad']['CFBundlePrimaryIcon']['CFBundleIconName'] == 'AppIconPad'
 assert int(re.search(r'\d+', info['DTSDKName']).group()) >= 26
print(f'{args.platform}: Release 번들·아이콘·문서·개인정보 명세·아키텍처 검증 통과 ({info["CFBundleShortVersionString"]})')
