#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the NutriLensHomeWidget WidgetKit extension to Runner.xcodeproj.
#
# Run from `ios/` working directory (or pass the project path as arg).
# Idempotent: re-running with the target already present is a no-op.
#
# Why this script exists: the project owner builds iOS only via Codemagic
# (Windows host, no Xcode). Hand-editing the pbxproj to add a new target
# is ~200 lines of UUID-keyed entries and one missed reference breaks
# the project file irrecoverably. The `xcodeproj` Ruby gem (the same one
# CocoaPods uses) does this correctly via the Apple project format.
#
# What this script wires up:
#   1. New PBXNativeTarget `NutriLensHomeWidget` of type :app_extension
#   2. Build configs (Debug + Release) inheriting from project defaults
#   3. Compile phase listing the Swift source
#   4. Resources phase listing the entitlements (handled via build setting)
#   5. Frameworks phase linking WidgetKit + SwiftUI
#   6. `Embed Foundation Extensions` copy-files phase on Runner that
#      embeds the widget's `.appex` into the host app
#   7. Runner target dependency on the widget so it builds first
#   8. Runner's `CODE_SIGN_ENTITLEMENTS` pointing at Runner/Runner.entitlements
#      (gives the host app access to the shared App Group)

require 'xcodeproj'

PROJECT_PATH = ARGV[0] || 'Runner.xcodeproj'
WIDGET_TARGET = 'NutriLensHomeWidget'
WIDGET_BUNDLE = 'app.nutrilens.ios.NutriLensHomeWidget'
WIDGET_FOLDER = 'NutriLensHomeWidget'
DEPLOYMENT_TARGET = '15.5'
SWIFT_VERSION = '5.0'

abort "project not found at #{PROJECT_PATH}" unless File.exist?(PROJECT_PATH)

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless runner

if project.targets.any? { |t| t.name == WIDGET_TARGET }
  puts "[add_widget_target] '#{WIDGET_TARGET}' already exists; nothing to do."
  exit 0
end

puts "[add_widget_target] creating target '#{WIDGET_TARGET}'..."

# 1. The target itself ────────────────────────────────────────────────────
widget = project.new_target(
  :app_extension,
  WIDGET_TARGET,
  :ios,
  DEPLOYMENT_TARGET,
  project.products_group,
  :swift
)

# 2. Source file group + reference ────────────────────────────────────────
# Reuse an existing group if a previous run created one (paranoia for
# partially-applied runs); otherwise create fresh.
widget_group = project.main_group.find_subpath(WIDGET_FOLDER, true)
widget_group.set_source_tree('<group>')
widget_group.set_path(WIDGET_FOLDER)

swift_ref = widget_group.find_file_by_path("#{WIDGET_FOLDER}/#{WIDGET_TARGET}.swift") ||
            widget_group.new_file("#{WIDGET_TARGET}.swift")
plist_ref = widget_group.find_file_by_path("#{WIDGET_FOLDER}/Info.plist") ||
            widget_group.new_file('Info.plist')
entitlements_ref = widget_group.find_file_by_path("#{WIDGET_FOLDER}/#{WIDGET_TARGET}.entitlements") ||
                   widget_group.new_file("#{WIDGET_TARGET}.entitlements")

widget.source_build_phase.add_file_reference(swift_ref, true)
# Info.plist + entitlements aren't compiled — they're referenced via
# build settings only. Keep them as file refs in the group for visibility.
_ = plist_ref
_ = entitlements_ref

# 3. Frameworks ───────────────────────────────────────────────────────────
frameworks_group = project.frameworks_group
%w[WidgetKit.framework SwiftUI.framework].each do |name|
  fw_ref = frameworks_group.find_file_by_path("System/Library/Frameworks/#{name}") ||
           frameworks_group.new_file("System/Library/Frameworks/#{name}", :sdk_root)
  widget.frameworks_build_phase.add_file_reference(fw_ref, true)
end

# 4. Build settings ───────────────────────────────────────────────────────
widget.build_configurations.each do |config|
  config.build_settings.merge!(
    'INFOPLIST_FILE'                  => "#{WIDGET_FOLDER}/Info.plist",
    'PRODUCT_BUNDLE_IDENTIFIER'       => WIDGET_BUNDLE,
    'PRODUCT_NAME'                    => '$(TARGET_NAME)',
    'PRODUCT_BUNDLE_PACKAGE_TYPE'     => 'XPC!',
    'WRAPPER_EXTENSION'               => 'appex',
    'CODE_SIGN_ENTITLEMENTS'          => "#{WIDGET_FOLDER}/#{WIDGET_TARGET}.entitlements",
    'IPHONEOS_DEPLOYMENT_TARGET'      => DEPLOYMENT_TARGET,
    'SWIFT_VERSION'                   => SWIFT_VERSION,
    'TARGETED_DEVICE_FAMILY'          => '1,2',
    'GENERATE_INFOPLIST_FILE'         => 'NO',
    # Manual signing on CI: Codemagic's `xcode-project use-profiles`
    # patches DEVELOPMENT_TEAM, PROVISIONING_PROFILE_SPECIFIER and
    # CODE_SIGN_IDENTITY at build time based on the App Store Connect
    # integration. Automatic style would try to log in to Xcode's
    # signing UI and fail on a headless runner.
    'CODE_SIGN_STYLE'                 => 'Manual',
    'SKIP_INSTALL'                    => 'NO',
    'LD_RUNPATH_SEARCH_PATHS'         =>
      '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
    'MARKETING_VERSION'               => '$(MARKETING_VERSION)',
    'CURRENT_PROJECT_VERSION'         => '$(CURRENT_PROJECT_VERSION)',
    'INFOPLIST_KEY_CFBundleDisplayName' => 'NutriLens Widget'
  )
end

# 5. Embed extension into Runner ──────────────────────────────────────────
# We use a `Copy Files` phase with destination `:plug_ins` (not a Run
# Script with cp) because Xcode's IPA packager only picks up app
# extensions from declared Copy-Files PlugIns phases. A Run Script that
# manually copies the .appex into TARGET_BUILD_DIR succeeds at build
# time but the bundle is skipped during IPA assembly — leading to
# `NutriLensHomeWidget.appex is missing from Runner.app/PlugIns` in
# the validate step.
#
# The previous "Cycle inside Runner" error from this phase + Flutter's
# Thin Binary + CocoaPods Embed Pods Frameworks is addressed below by
# disabling Xcode 16's user-script sandboxing on the Runner target —
# the sandbox is what reports overly-strict implicit deps between
# phases that all touch Runner.app.

# Remove any previous embed phase (Copy-Files OR Run Script) from
# earlier script runs to keep idempotency.
runner.build_phases.delete_if do |p|
  p.respond_to?(:name) && p.name == 'Embed Foundation Extensions'
end

embed_phase = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_phase.add_file_reference(widget.product_reference, true)

# Use Apple's default phase ordering (embed at the end, after Thin
# Binary). With ENABLE_USER_SCRIPT_SANDBOXING=NO below, this no longer
# triggers the implicit-deps cycle.

# 6. Runner depends on widget (forces widget to build first) ──────────────
runner.add_dependency(widget) unless runner.dependencies.any? { |d| d.target == widget }

# 7. Runner entitlements path (App Group + future capabilities) ──────────
# Also disable Xcode 16's user-script sandboxing on Runner so the
# Embed Foundation Extensions Copy phase, Flutter's Thin Binary
# script, and CocoaPods' Embed Pods Frameworks script can each touch
# Runner.app/ without the sandbox flagging them as a dependency cycle.
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

# Apply the same sandbox-disable to the widget target so its post-
# build phases (signing, embedding) play nicely with the host.
widget.build_configurations.each do |config|
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

project.save
puts "[add_widget_target] done — pbxproj updated."
