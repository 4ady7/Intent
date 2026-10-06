#!/usr/bin/env python3
"""Generate Focus.xcodeproj. Re-run only if you want to rebuild the project file from the source tree."""

import os
from pathlib import Path

ROOT = Path("/Users/shady/Downloads/Intent")
PROJ = ROOT / "Focus.xcodeproj"

counter = 0x1000

def nid():
    global counter
    counter += 1
    return f"F{counter:023X}"

def q(value: str) -> str:
    if value == "":
        return '""'
    if any(ch in value for ch in ' "\';=$()+') or value.startswith("-"):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return value

files = {}
groups = {}

def add_file(path: Path):
    rel = path.relative_to(ROOT).as_posix()
    if rel in files:
        return files[rel]
    fid = nid()
    kind = "sourcecode.swift" if path.suffix == ".swift" else None
    if path.suffix == ".plist":
        kind = "text.plist.xml"
    elif path.suffix == ".xcconfig":
        kind = "text.xcconfig"
    elif path.suffix == ".entitlements":
        kind = "text.plist.entitlements"
    elif path.suffix == ".xcprivacy":
        kind = "text.xml"
    elif path.name == "Contents.json":
        kind = "text.json"
    elif path.suffix == ".png":
        kind = "image.png"
    elif path.suffix == ".xcassets":
        kind = "folder.assetcatalog"
    files[rel] = {"id": fid, "path": rel, "name": path.name, "kind": kind, "build": {}}
    return files[rel]

def ensure_group(dir_rel: str):
    if dir_rel in groups:
        return groups[dir_rel]
    gid = nid()
    groups[dir_rel] = {"id": gid, "children": [], "path": Path(dir_rel).name if dir_rel else None}
    if dir_rel:
        parent = str(Path(dir_rel).parent)
        if parent == ".":
            parent = ""
        ensure_group(parent)
        groups[parent]["children"].append(("group", gid, Path(dir_rel).name))
    return groups[dir_rel]

# Collect sources
swift_by_top = {"Shared": [], "Focus": [], "FocusMonitor": [], "FocusShieldConfiguration": [], "FocusShieldAction": [], "FocusTests": []}
for top in swift_by_top:
    for path in sorted((ROOT / top).rglob("*.swift")):
        swift_by_top[top].append(path.relative_to(ROOT).as_posix())
        add_file(path)
        ensure_group(str(path.parent.relative_to(ROOT)))

extra = [
    "Config/Shared.xcconfig",
    "Config/Focus.entitlements",
    "Focus/Resources/PrivacyInfo.xcprivacy",
    "Focus/Resources/Assets.xcassets",
    "FocusMonitor/Info.plist",
    "FocusShieldConfiguration/Info.plist",
    "FocusShieldAction/Info.plist",
]
for rel in extra:
    add_file(ROOT / rel)
    ensure_group(str((ROOT / rel).parent.relative_to(ROOT)))

# Asset catalog is a folder reference, not individual files.
assets_rel = "Focus/Resources/Assets.xcassets"
files[assets_rel]["kind"] = "folder.assetcatalog"
files[assets_rel]["last_known"] = "0"

shared = swift_by_top["Shared"]
monitor_names = {
    "FocusIdentifiers.swift", "FocusDuration.swift", "FocusError.swift", "FocusLog.swift",
    "SessionPhase.swift", "PersistedSelection.swift", "FocusSession.swift", "FocusPreset.swift",
    "SessionStateMachine.swift", "SessionClock.swift", "FocusFileIO.swift", "FocusStore.swift",
    "BlockingService.swift", "MonitorPolicy.swift",
}
shield_names = {
    "FocusIdentifiers.swift", "FocusDuration.swift", "FocusError.swift", "FocusLog.swift",
    "SessionPhase.swift", "PersistedSelection.swift", "FocusSession.swift", "FocusPreset.swift",
    "SessionStateMachine.swift", "SessionClock.swift", "FocusFileIO.swift", "FocusStore.swift",
    "ShieldCopy.swift",
}

def named(paths, names):
    return [p for p in paths if Path(p).name in names]

app_sources = shared + swift_by_top["Focus"]
monitor_sources = named(shared, monitor_names) + swift_by_top["FocusMonitor"]
shield_sources = named(shared, shield_names) + swift_by_top["FocusShieldConfiguration"]
action_sources = swift_by_top["FocusShieldAction"]
test_sources = shared + swift_by_top["FocusTests"]

app_resources = [assets_rel, "Focus/Resources/PrivacyInfo.xcprivacy"]

# IDs
project_id = nid()
app_target = nid()
monitor_target = nid()
shield_target = nid()
action_target = nid()
test_target = nid()
app_product = nid()
monitor_product = nid()
shield_product = nid()
action_product = nid()
test_product = nid()
main_group = nid()
products_group = nid()
sources_phase = {app_target: nid(), monitor_target: nid(), shield_target: nid(), action_target: nid(), test_target: nid()}
frameworks_phase = {app_target: nid(), monitor_target: nid(), shield_target: nid(), action_target: nid(), test_target: nid()}
resources_phase = nid()
embed_phase = nid()
config_list = {project_id: nid(), app_target: nid(), monitor_target: nid(), shield_target: nid(), action_target: nid(), test_target: nid()}
debug_config = {}
release_config = {}
for owner in config_list:
    debug_config[owner] = nid()
    release_config[owner] = nid()
proxy = {monitor_target: nid(), shield_target: nid(), action_target: nid()}
dependency = {monitor_target: nid(), shield_target: nid(), action_target: nid()}
embed_build = {monitor_product: nid(), shield_product: nid(), action_product: nid()}

# Build files
build_files = []

def add_build(file_rel, target, phase_kind):
    bid = nid()
    files[file_rel]["build"].setdefault(target, []).append((bid, phase_kind))
    build_files.append((bid, files[file_rel]["id"], phase_kind, None))
    return bid

for rel in app_sources:
    add_build(rel, app_target, "Sources")
for rel in app_resources:
    add_build(rel, app_target, "Resources")
for rel in monitor_sources:
    add_build(rel, monitor_target, "Sources")
for rel in shield_sources:
    add_build(rel, shield_target, "Sources")
for rel in action_sources:
    add_build(rel, action_target, "Sources")
for rel in test_sources:
    add_build(rel, test_target, "Sources")

# Products
products = {
    app_product: ("Focus.app", "wrapper.application", app_target),
    monitor_product: ("FocusMonitor.appex", "wrapper.app-extension", monitor_target),
    shield_product: ("FocusShieldConfiguration.appex", "wrapper.app-extension", shield_target),
    action_product: ("FocusShieldAction.appex", "wrapper.app-extension", action_target),
    test_product: ("FocusTests.xctest", "wrapper.cfbundle", test_target),
}

def build_file_lines():
    lines = ["/* Begin PBXBuildFile section */"]
    for bid, fid, kind, _ in build_files:
        comment = next(rel for rel, meta in files.items() if meta["id"] == fid)
        lines.append(f"\t\t{bid} /* {Path(comment).name} in {kind} */ = {{isa = PBXBuildFile; fileRef = {fid} /* {Path(comment).name} */; }};")
    for product, bid in embed_build.items():
        name = products[product][0]
        lines.append(f"\t\t{bid} /* {name} in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {product} /* {name} */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, CodeSignOnCopy, ); }}; }};")
    lines.append("/* End PBXBuildFile section */")
    return lines

def file_ref_lines():
    lines = ["/* Begin PBXFileReference section */"]
    for rel, meta in files.items():
        kind = meta["kind"]
        explicit = ""
        if kind:
            explicit = f" explicitFileType = {kind};" if kind.startswith("folder") or kind.startswith("wrapper") else f" lastKnownFileType = {kind};"
        if kind == "folder.assetcatalog":
            explicit = " lastKnownFileType = folder.assetcatalog;"
        lines.append(f"\t\t{meta['id']} /* {meta['name']} */ = {{isa = PBXFileReference;{explicit} path = {q(meta['name'])}; sourceTree = \"<group>\"; }};")
    for pid, (name, ftype, _) in products.items():
        lines.append(f"\t\t{pid} /* {name} */ = {{isa = PBXFileReference; explicitFileType = {q(ftype)}; includeInIndex = 0; path = {q(name)}; sourceTree = BUILT_PRODUCTS_DIR; }};")
    lines.append("/* End PBXFileReference section */")
    return lines

# Groups: children are file ids in that directory or subgroup ids
# Rebuild children properly
for g in groups.values():
    g["file_children"] = []

for rel, meta in files.items():
    parent = str(Path(rel).parent)
    if parent == ".":
        parent = ""
    ensure_group(parent)
    groups[parent]["file_children"].append(meta)

def group_lines():
    lines = ["/* Begin PBXGroup section */"]
    # root
    root_children = []
    for key in ["Config", "Shared", "Focus", "FocusMonitor", "FocusShieldConfiguration", "FocusShieldAction", "FocusTests"]:
        if key in groups:
            root_children.append(f"{groups[key]['id']} /* {key} */")
    root_children.append(f"{products_group} /* Products */")
    lines.append(f"\t\t{main_group} = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for child in root_children:
        lines.append(f"\t\t\t\t{child},")
    lines.append("\t\t\t);")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append(f"\t\t{products_group} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for pid, (name, _, _) in products.items():
        lines.append(f"\t\t\t\t{pid} /* {name} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    for rel, group in groups.items():
        if rel == "":
            continue
        lines.append(f"\t\t{group['id']} /* {Path(rel).name} */ = {{")
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        child_groups = [g for grel, g in groups.items() if grel != rel and str(Path(grel).parent) == (rel if rel else ".")]
        # parent of "Config" is "." which we stored as ""
        child_groups = []
        for grel, g in groups.items():
            parent = str(Path(grel).parent)
            if parent == ".":
                parent = ""
            if grel and parent == rel:
                child_groups.append((Path(grel).name, g["id"]))
        for name, gid in sorted(child_groups):
            lines.append(f"\t\t\t\t{gid} /* {name} */,")
        for meta in sorted(group["file_children"], key=lambda m: m["name"]):
            lines.append(f"\t\t\t\t{meta['id']} /* {meta['name']} */,")
        lines.append("\t\t\t);")
        lines.append(f"\t\t\tpath = {q(Path(rel).name)};")
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")
    lines.append("/* End PBXGroup section */")
    return lines

def phase(phase_id, name, isa, file_ids, extra=""):
    lines = [f"\t\t{phase_id} /* {name} */ = {{", f"\t\t\tisa = {isa};", "\t\t\tbuildActionMask = 2147483647;", "\t\t\tfiles = ("]
    for fid in file_ids:
        lines.append(f"\t\t\t\t{fid},")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    if extra:
        lines.append(extra)
    lines.append("\t\t};")
    return lines

def sources_for(target, rels):
    ids = []
    for rel in rels:
        for bid, kind in [(b, k) for b, k in ((item[0], item[2]) for item in [(bid, files[rel]["id"], "Sources") for bid, _, kind, _ in []])] :
            pass
    ids = []
    for rel in rels:
        for bid, fid, kind, _ in build_files:
            if fid == files[rel]["id"] and kind == "Sources":
                # A file can be in multiple targets; match the build file that was created for this target.
                pass
    # Use stored mapping
    ids = []
    for rel in rels:
        for bid, kind in [(pair[0], pair[1]) for pair in files[rel]["build"].get(target, [])]:
            if kind == "Sources":
                ids.append(f"{bid} /* {Path(rel).name} in Sources */")
    return ids

def resources_for():
    ids = []
    for rel in app_resources:
        for bid, kind in files[rel]["build"].get(app_target, []):
            ids.append(f"{bid} /* {Path(rel).name} in Resources */")
    return ids

project_debug = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": "DEBUG=1 $(inherited)",
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1",
}

project_release = dict(project_debug)
project_release.update({
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "ENABLE_TESTABILITY": "NO",
    "GCC_OPTIMIZATION_LEVEL": "s",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
    "VALIDATE_PRODUCT": "YES",
})
del project_release["GCC_PREPROCESSOR_DEFINITIONS"]
del project_release["SWIFT_ACTIVE_COMPILATION_CONDITIONS"]
project_release["COPY_PHASE_STRIP"] = "NO"

common_target = {
    "CODE_SIGN_ENTITLEMENTS": "Config/Focus.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": "",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "Focus",
    "INFOPLIST_KEY_FocusAppGroupIdentifier": "$(FOCUS_APP_GROUP)",
    "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "$(FOCUS_BUNDLE_ID)",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SDKROOT": "iphoneos",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1",
}

app_settings = dict(common_target)
app_settings.update({
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "ENABLE_PREVIEWS": "YES",
    "INFOPLIST_KEY_NSFamilyControlsUsageDescription": "Focus uses Screen Time to temporarily restrict the apps you choose during a focus session. Selections stay on this device.",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
    "SUPPORTS_MACCATALYST": "NO",
    "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
    "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
})

def extension_settings(bundle_suffix, display, plist):
    settings = dict(common_target)
    settings.update({
        "APPLICATION_EXTENSION_API_ONLY": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": plist,
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
        "PRODUCT_BUNDLE_IDENTIFIER": f"$(FOCUS_BUNDLE_ID).{bundle_suffix}",
        "SKIP_INSTALL": "YES",
    })
    settings.pop("INFOPLIST_KEY_CFBundleDisplayName", None)
    settings.pop("INFOPLIST_KEY_FocusAppGroupIdentifier", None)
    settings.pop("INFOPLIST_KEY_ITSAppUsesNonExemptEncryption", None)
    return settings

test_settings = dict(common_target)
test_settings.update({
    "BUNDLE_LOADER": "",
    "CODE_SIGN_ENTITLEMENTS": "",
    "GENERATE_INFOPLIST_FILE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "$(FOCUS_BUNDLE_ID)Tests",
    "SDKROOT": "iphoneos",
    "TEST_HOST": "",
})
for key in ["INFOPLIST_KEY_CFBundleDisplayName", "INFOPLIST_KEY_FocusAppGroupIdentifier", "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption"]:
    test_settings.pop(key, None)

target_settings = {
    app_target: app_settings,
    monitor_target: extension_settings("Monitor", "Focus Monitor", "FocusMonitor/Info.plist"),
    shield_target: extension_settings("ShieldConfiguration", "Focus Shield", "FocusShieldConfiguration/Info.plist"),
    action_target: extension_settings("ShieldAction", "Focus Shield Action", "FocusShieldAction/Info.plist"),
    test_target: test_settings,
}

def settings_block(mapping):
    lines = ["\t\t\tbuildSettings = {"]
    for key in sorted(mapping):
        lines.append(f"\t\t\t\t{key} = {q(mapping[key])};")
    lines.append("\t\t\t};")
    return lines

def config_block(cid, name, base_settings, xcconfig):
    lines = [f"\t\t{cid} /* {name} */ = {{", "\t\t\tisa = XCBuildConfiguration;"]
    if xcconfig:
        lines.append(f"\t\t\tbaseConfigurationReference = {files['Config/Shared.xcconfig']['id']} /* Shared.xcconfig */;")
    lines += settings_block(base_settings)
    lines.append(f"\t\t\tname = {name};")
    lines.append("\t\t};")
    return lines

out = []
out.append("// !$*UTF8*$!")
out.append("{")
out.append("\tarchiveVersion = 1;")
out.append("\tclasses = {")
out.append("\t};")
out.append("\tobjectVersion = 60;")
out.append("\tobjects = {")
out.append("")
out += build_file_lines()
out.append("")
out += file_ref_lines()
out.append("")

# Phases
out.append("/* Begin PBXSourcesBuildPhase section */")
for target, rels in [
    (app_target, app_sources),
    (monitor_target, monitor_sources),
    (shield_target, shield_sources),
    (action_target, action_sources),
    (test_target, test_sources),
]:
    out += phase(sources_phase[target], "Sources", "PBXSourcesBuildPhase", sources_for(target, rels))
out.append("/* End PBXSourcesBuildPhase section */")
out.append("")

out.append("/* Begin PBXFrameworksBuildPhase section */")
for target in [app_target, monitor_target, shield_target, action_target, test_target]:
    out += phase(frameworks_phase[target], "Frameworks", "PBXFrameworksBuildPhase", [])
out.append("/* End PBXFrameworksBuildPhase section */")
out.append("")

out.append("/* Begin PBXResourcesBuildPhase section */")
out += phase(resources_phase, "Resources", "PBXResourcesBuildPhase", resources_for())
out.append("/* End PBXResourcesBuildPhase section */")
out.append("")

out.append("/* Begin PBXCopyFilesBuildPhase section */")
embed_ids = [f"{embed_build[monitor_product]} /* FocusMonitor.appex in Embed Foundation Extensions */",
             f"{embed_build[shield_product]} /* FocusShieldConfiguration.appex in Embed Foundation Extensions */",
             f"{embed_build[action_product]} /* FocusShieldAction.appex in Embed Foundation Extensions */"]
out.append(f"\t\t{embed_phase} /* Embed Foundation Extensions */ = {{")
out.append("\t\t\tisa = PBXCopyFilesBuildPhase;")
out.append("\t\t\tbuildActionMask = 2147483647;")
out.append('\t\t\tdstPath = "";')
out.append("\t\t\tdstSubfolderSpec = 13;")
out.append("\t\t\tfiles = (")
for item in embed_ids:
    out.append(f"\t\t\t\t{item},")
out.append("\t\t\t);")
out.append('\t\t\tname = "Embed Foundation Extensions";')
out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
out.append("\t\t};")
out.append("/* End PBXCopyFilesBuildPhase section */")
out.append("")

out += group_lines()
out.append("")

out.append("/* Begin PBXNativeTarget section */")

def target_block(tid, name, product_type, product_id, phases, deps):
    lines = [f"\t\t{tid} /* {name} */ = {{", "\t\t\tisa = PBXNativeTarget;", f"\t\t\tbuildConfigurationList = {config_list[tid]} /* Build configuration list for PBXNativeTarget \"{name}\" */;", "\t\t\tbuildPhases = ("]
    for phase_id, phase_name in phases:
        lines.append(f"\t\t\t\t{phase_id} /* {phase_name} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdependencies = (")
    for dep in deps:
        lines.append(f"\t\t\t\t{dep},")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tname = {q(name)};")
    pname = products[product_id][0]
    lines.append(f"\t\t\tproductName = {q(name)};")
    lines.append(f"\t\t\tproductReference = {product_id} /* {pname} */;")
    lines.append(f"\t\t\tproductType = {q(product_type)};")
    lines.append("\t\t};")
    return lines

out += target_block(app_target, "Focus", "com.apple.product-type.application", app_product, [
    (sources_phase[app_target], "Sources"),
    (frameworks_phase[app_target], "Frameworks"),
    (resources_phase, "Resources"),
    (embed_phase, "Embed Foundation Extensions"),
], [dependency[monitor_target], dependency[shield_target], dependency[action_target]])
out += target_block(monitor_target, "FocusMonitor", "com.apple.product-type.app-extension", monitor_product, [
    (sources_phase[monitor_target], "Sources"),
    (frameworks_phase[monitor_target], "Frameworks"),
], [])
out += target_block(shield_target, "FocusShieldConfiguration", "com.apple.product-type.app-extension", shield_product, [
    (sources_phase[shield_target], "Sources"),
    (frameworks_phase[shield_target], "Frameworks"),
], [])
out += target_block(action_target, "FocusShieldAction", "com.apple.product-type.app-extension", action_product, [
    (sources_phase[action_target], "Sources"),
    (frameworks_phase[action_target], "Frameworks"),
], [])
out += target_block(test_target, "FocusTests", "com.apple.product-type.bundle.unit-test", test_product, [
    (sources_phase[test_target], "Sources"),
    (frameworks_phase[test_target], "Frameworks"),
], [])
out.append("/* End PBXNativeTarget section */")
out.append("")

out.append("/* Begin PBXProject section */")
out.append(f"\t\t{project_id} /* Project object */ = {{")
out.append("\t\t\tisa = PBXProject;")
out.append("\t\t\tattributes = {")
out.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
out.append("\t\t\t\tLastUpgradeCheck = 1620;")
out.append("\t\t\t\tTargetAttributes = {")
for tid in [app_target, monitor_target, shield_target, action_target, test_target]:
    out.append(f"\t\t\t\t\t{tid} = {{")
    out.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.2;")
    out.append("\t\t\t\t\t};")
out.append("\t\t\t\t};")
out.append("\t\t\t};")
out.append(f"\t\t\tbuildConfigurationList = {config_list[project_id]} /* Build configuration list for PBXProject \"Focus\" */;")
out.append('\t\t\tcompatibilityVersion = "Xcode 15.0";')
out.append("\t\t\tdevelopmentRegion = en;")
out.append("\t\t\thasScannedForEncodings = 0;")
out.append("\t\t\tknownRegions = (")
out.append("\t\t\t\ten,")
out.append("\t\t\t\tBase,")
out.append("\t\t\t);")
out.append(f"\t\t\tmainGroup = {main_group};")
out.append(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
out.append('\t\t\tprojectDirPath = "";')
out.append('\t\t\tprojectRoot = "";')
out.append("\t\t\ttargets = (")
for tid, name in [(app_target, "Focus"), (monitor_target, "FocusMonitor"), (shield_target, "FocusShieldConfiguration"), (action_target, "FocusShieldAction"), (test_target, "FocusTests")]:
    out.append(f"\t\t\t\t{tid} /* {name} */,")
out.append("\t\t\t);")
out.append("\t\t};")
out.append("/* End PBXProject section */")
out.append("")

out.append("/* Begin PBXContainerItemProxy section */")
for tid, name in [(monitor_target, "FocusMonitor"), (shield_target, "FocusShieldConfiguration"), (action_target, "FocusShieldAction")]:
    out.append(f"\t\t{proxy[tid]} /* PBXContainerItemProxy */ = {{")
    out.append("\t\t\tisa = PBXContainerItemProxy;")
    out.append("\t\t\tcontainerPortal = " + project_id + " /* Project object */;")
    out.append("\t\t\tproxyType = 1;")
    out.append(f"\t\t\tremoteGlobalIDString = {tid};")
    out.append(f"\t\t\tremoteInfo = {q(name)};")
    out.append("\t\t};")
out.append("/* End PBXContainerItemProxy section */")
out.append("")

out.append("/* Begin PBXTargetDependency section */")
for tid, name in [(monitor_target, "FocusMonitor"), (shield_target, "FocusShieldConfiguration"), (action_target, "FocusShieldAction")]:
    out.append(f"\t\t{dependency[tid]} /* PBXTargetDependency */ = {{")
    out.append("\t\t\tisa = PBXTargetDependency;")
    out.append(f"\t\t\ttarget = {tid} /* {name} */;")
    out.append(f"\t\t\ttargetProxy = {proxy[tid]} /* PBXContainerItemProxy */;")
    out.append("\t\t};")
out.append("/* End PBXTargetDependency section */")
out.append("")

out.append("/* Begin XCBuildConfiguration section */")
out += config_block(debug_config[project_id], "Debug", project_debug, True)
out += config_block(release_config[project_id], "Release", project_release, True)
for tid in [app_target, monitor_target, shield_target, action_target, test_target]:
    out += config_block(debug_config[tid], "Debug", target_settings[tid], False)
    out += config_block(release_config[tid], "Release", target_settings[tid], False)
out.append("/* End XCBuildConfiguration section */")
out.append("")

out.append("/* Begin XCConfigurationList section */")
def config_list_block(lid, owner_name, debug_id, release_id):
    return [
        f"\t\t{lid} /* Build configuration list for {owner_name} */ = {{",
        "\t\t\tisa = XCConfigurationList;",
        "\t\t\tbuildConfigurations = (",
        f"\t\t\t\t{debug_id} /* Debug */,",
        f"\t\t\t\t{release_id} /* Release */,",
        "\t\t\t);",
        "\t\t\tdefaultConfigurationIsVisible = 0;",
        "\t\t\tdefaultConfigurationName = Release;",
        "\t\t};",
    ]
out += config_list_block(config_list[project_id], 'PBXProject "Focus"', debug_config[project_id], release_config[project_id])
for tid, name in [(app_target, "Focus"), (monitor_target, "FocusMonitor"), (shield_target, "FocusShieldConfiguration"), (action_target, "FocusShieldAction"), (test_target, "FocusTests")]:
    out += config_list_block(config_list[tid], f'PBXNativeTarget "{name}"', debug_config[tid], release_config[tid])
out.append("/* End XCConfigurationList section */")

out.append("\t};")
out.append(f"\trootObject = {project_id} /* Project object */;")
out.append("}")
out.append("")

PROJ.mkdir(exist_ok=True)
(PROJ / "project.pbxproj").write_text("\n".join(out))
workspace = PROJ / "project.xcworkspace"
workspace.mkdir(exist_ok=True)
(workspace / "contents.xcworkspacedata").write_text("""<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<Workspace
   version = \"1.0\">
   <FileRef
      location = \"self:\">
   </FileRef>
</Workspace>
""")
scheme_dir = PROJ / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f"""<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<Scheme
   LastUpgradeVersion = \"1620\"
   version = \"1.7\">
   <BuildAction
      parallelizeBuildables = \"YES\"
      buildImplicitDependencies = \"YES\">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = \"YES\"
            buildForRunning = \"YES\"
            buildForProfiling = \"YES\"
            buildForArchiving = \"YES\"
            buildForAnalyzing = \"YES\">
            <BuildableReference
               BuildableIdentifier = \"primary\"
               BlueprintIdentifier = \"{app_target}\"
               BuildableName = \"Focus.app\"
               BlueprintName = \"Focus\"
               ReferencedContainer = \"container:Focus.xcodeproj\">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = \"YES\"
            buildForRunning = \"NO\"
            buildForProfiling = \"NO\"
            buildForArchiving = \"NO\"
            buildForAnalyzing = \"NO\">
            <BuildableReference
               BuildableIdentifier = \"primary\"
               BlueprintIdentifier = \"{test_target}\"
               BuildableName = \"FocusTests.xctest\"
               BlueprintName = \"FocusTests\"
               ReferencedContainer = \"container:Focus.xcodeproj\">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = \"Debug\"
      selectedDebuggerIdentifier = \"Xcode.DebuggerFoundation.Debugger.LLDB\"
      selectedLauncherIdentifier = \"Xcode.DebuggerFoundation.Launcher.LLDB\"
      shouldUseLaunchSchemeArgsEnv = \"YES\">
      <Testables>
         <TestableReference
            skipped = \"NO\">
            <BuildableReference
               BuildableIdentifier = \"primary\"
               BlueprintIdentifier = \"{test_target}\"
               BuildableName = \"FocusTests.xctest\"
               BlueprintName = \"FocusTests\"
               ReferencedContainer = \"container:Focus.xcodeproj\">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = \"Debug\"
      selectedDebuggerIdentifier = \"Xcode.DebuggerFoundation.Debugger.LLDB\"
      selectedLauncherIdentifier = \"Xcode.DebuggerFoundation.Launcher.LLDB\"
      launchStyle = \"0\"
      useCustomWorkingDirectory = \"NO\"
      ignoresPersistentStateOnLaunch = \"NO\"
      debugDocumentVersioning = \"YES\"
      debugServiceExtension = \"internal\"
      allowLocationSimulation = \"YES\">
      <BuildableProductRunnable
         runnableDebuggingMode = \"0\">
         <BuildableReference
            BuildableIdentifier = \"primary\"
            BlueprintIdentifier = \"{app_target}\"
            BuildableName = \"Focus.app\"
            BlueprintName = \"Focus\"
            ReferencedContainer = \"container:Focus.xcodeproj\">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = \"Release\"
      shouldUseLaunchSchemeArgsEnv = \"YES\"
      savedToolIdentifier = \"\"
      useCustomWorkingDirectory = \"NO\"
      debugDocumentVersioning = \"YES\">
      <BuildableProductRunnable
         runnableDebuggingMode = \"0\">
         <BuildableReference
            BuildableIdentifier = \"primary\"
            BlueprintIdentifier = \"{app_target}\"
            BuildableName = \"Focus.app\"
            BlueprintName = \"Focus\"
            ReferencedContainer = \"container:Focus.xcodeproj\">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = \"Debug\">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = \"Release\"
      revealArchiveInOrganizer = \"YES\">
   </ArchiveAction>
</Scheme>
"""
(scheme_dir / "Focus.xcscheme").write_text(scheme)
print(f"Wrote project with {len(files)} files")
print("App sources", len(app_sources))
print("Monitor", len(monitor_sources))
print("Shield", len(shield_sources))
print("Action", len(action_sources))
print("Tests", len(test_sources))
missing_monitor = monitor_names - {Path(p).name for p in monitor_sources}
missing_shield = shield_names - {Path(p).name for p in shield_sources}
print("Missing monitor", missing_monitor)
print("Missing shield", missing_shield)
