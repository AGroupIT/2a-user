"""Generate the unsigned diagnostic target with Python stdlib; no portal access."""
import hashlib
import plistlib
from pathlib import Path

root = Path(__file__).resolve().parent
objects = {}


def add(key, isa, **values):
    identifier = hashlib.sha256(key.encode()).hexdigest()[:24].upper()
    objects[identifier] = dict(isa=isa, **values)
    return identifier


files = ['ProbeApp.swift', 'CaptureSource.swift', 'SampleBufferPiP.swift', 'SessionGate.swift', 'QAClipWriter.swift', 'ScreenOCRCore.swift', 'MockScreenTranslator.swift', 'ScreenOCRPipeline.swift', 'ScreenFramePainter.swift', 'ScreenFrameSampler.swift', 'ScreenTranslationClient.swift']
references = [add(f, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=f, sourceTree='<group>') for f in files]
sources = add('sources', 'PBXSourcesBuildPhase', buildActionMask=2147483647,
              files=[add('build-'+f, 'PBXBuildFile', fileRef=r) for f, r in zip(files, references)], runOnlyForDeploymentPostprocessing=0)
frameworks = add('frameworks', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
product = add('product', 'PBXFileReference', explicitFileType='wrapper.application', path='ScreenTranslationProbe.app', sourceTree='BUILT_PRODUCTS_DIR')
products = add('products', 'PBXGroup', children=[product], name='Products', sourceTree='<group>')
main = add('main', 'PBXGroup', children=references+[products], sourceTree='<group>')


def configurations(prefix, settings):
    configs = [add(prefix+name, 'XCBuildConfiguration', name=name, buildSettings={**settings, 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name == 'Debug' else '-O'}) for name in ['Debug', 'Release']]
    return add(prefix+'configs', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')


target_configs = configurations('target', dict(
    PRODUCT_NAME='ScreenTranslationProbe', PRODUCT_BUNDLE_IDENTIFIER='com.twoalogistic.user.screentranslationprobe',
    INFOPLIST_FILE='Info.plist', SWIFT_VERSION='5.0', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SCREEN_TRANSLATION_STANDALONE', IPHONEOS_DEPLOYMENT_TARGET='27.0',
    TARGETED_DEVICE_FAMILY='1', CODE_SIGN_STYLE='Automatic', DEVELOPMENT_TEAM='8DYZBYA8L9',
    SDKROOT='iphoneos', SUPPORTED_PLATFORMS='iphoneos iphonesimulator',
    LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks', ENABLE_USER_SCRIPT_SANDBOXING='YES'))
target = add('target', 'PBXNativeTarget', buildConfigurationList=target_configs, buildPhases=[sources, frameworks],
             buildRules=[], dependencies=[], name='ScreenTranslationProbe', productName='ScreenTranslationProbe', productReference=product,
             productType='com.apple.product-type.application')
project_configs = configurations('project', dict(CLANG_ENABLE_MODULES='YES', SDKROOT='iphoneos', IPHONEOS_DEPLOYMENT_TARGET='27.0'))
project = add('project', 'PBXProject', attributes={'LastUpgradeCheck': '2710'}, buildConfigurationList=project_configs,
              compatibilityVersion='Xcode 14.0', developmentRegion='ru', hasScannedForEncodings=0,
              knownRegions=['ru', 'zh-Hans', 'en'], mainGroup=main, productRefGroup=products,
              projectDirPath='', projectRoot='', targets=[target])
output = root/'ScreenTranslationProbe.xcodeproj'
output.mkdir(exist_ok=True)
(output/'project.pbxproj').write_bytes(plistlib.dumps(dict(archiveVersion='1', classes={}, objectVersion='56', objects=objects, rootObject=project)))
print(output)
