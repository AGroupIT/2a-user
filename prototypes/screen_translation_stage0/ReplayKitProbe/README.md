# ReplayKit metadata probe

Unsigned diagnostic preparation for a Broadcast Upload Extension embedded in the existing 2A User app. It does not establish that capture works on the test iPhone, that the host survives in the background, or that an extension can own/update PiP.

Proposed extension bundle ID: `com.twoalogistic.user.screenbroadcastprobe`. The containing app remains `com.twoalogistic.user`. Use the existing development team and certificate only when a signed test is authorized. An extension has its own bundle ID and needs a compatible extension provisioning profile; the existing Runner profile alone does not provision it. No App ID, profile, certificate, entitlement or Apple Developer setting is created by these sources. No App Group or IPC is configured.

## Runtime ownership and privacy

`SampleHandler` is instantiated in the system-managed broadcast extension process. It receives lifecycle and sample callbacks; the containing Flutter application does not own these callbacks. A lock protects concurrent callbacks, counters and the single metadata write. A fresh UUID identifies each start. Finish writes the terminal state then invalidates that session; later callbacks are ignored. There are no queued jobs, timers, retained sample buffers, image byte reads, OCR, translation, network calls or provider credentials.

All non-video callbacks return immediately, including app audio and microphone audio. No audio buffer format, timing, attachment or contents are inspected. This extension does not request microphone access. In the system broadcast UI keep Microphone **Off**; the system can still supply app-audio callbacks, which are discarded.

Video processing reads only validity/readiness, pixel-buffer dimensions/pixel-format FourCC, `RPVideoSampleOrientationKey`, and presentation time. Diagnostics contain only these values, counts, process ID, monotonic timings, fixed lifecycle names and session UUID. `setupInfo`, application identity, screen text and screenshots are not recorded or logged.

One fixed file, `ScreenTranslationReplayKitProbe.json`, is atomically replaced in the **extension's own Caches directory**, at most once per second during video delivery, plus start/pause/resume/finish. It contains the latest session only. Atomic replacement can create a transient filesystem temporary file; it is not an accumulating history. Caches are system-purgeable, so this is best-effort diagnostics. Failures increment a numeric counter without logging error strings. The host app cannot read this container through an ordinary path; extracting the metadata requires an authorized developer/device diagnostic workflow. There is no host-visible live status or stop IPC in this initial probe.

A force-kill or OS termination can prevent `broadcastFinished` from running: a persisted nonterminal state is not proof that capture remains active. There is no automatic restart. This probe has no PiP controller and does not translate.

## Unsigned preparation and future physical check

The parent project must create an isolated app-extension target using these files and conditionally embed its product into the diagnostic Runner build. Set `APPLICATION_EXTENSION_API_ONLY = YES`, the proposed bundle ID, `SKIP_INSTALL = YES`, and normal matching app/extension version fields. Do not embed this probe into default release builds.

Before any signed install, separately obtain approval for the extension App ID/profile and confirm a compatible existing Developer environment. Unsigned compilation cannot verify Control Center discoverability or provisioning. On an authorized device build, use iPhone Control Center → Screen Recording → **2A ReplayKit Probe**, keep microphone off, and explicitly start broadcasting. Test only synthetic or separately permitted content, then stop using the system broadcast control. Record extension metadata before interpreting any host/PiP lifecycle result.

## SDK verification and limitations

Verified against local iPhoneOS **27.1** headers in `ReplayKit.framework/Headers/RPBroadcastExtension.h`. `RPBroadcastSampleHandler`, `RPVideoSampleOrientationKey` and its superclass are deprecated in iOS **27.0**, annotated **“No longer supported”**. `RPSampleBufferType` is deprecated in iOS27 with **“Use SCStreamOutputType instead”**. These public declarations still compile; deprecation does not prove runtime availability, reliability, or approval eligibility. No replacement architecture is inferred from these annotations.

The SDK documents `RPBroadcastProcessModeSampleBuffer` and the orientation attachment's `CGImagePropertyOrientation` values. Actual callback delivery, orientation, frame rate, extension memory/lifetime, pause/resume, locking/interruption, Control Center stop and host-process termination remain unverified for this ReplayKit probe. No physical test is claimed here.

Independent typecheck: iOS15 deployment passes without warnings; iOS27 deployment passes with three expected deprecation warnings (`RPBroadcastSampleHandler`, `RPSampleBufferType`, `RPVideoSampleOrientationKey`). No warnings are suppressed.

```sh
xcrun swiftc -typecheck -application-extension \
  -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -target arm64-apple-ios15.0 SampleHandler.swift
xcrun swiftc -typecheck -application-extension \
  -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -target arm64-apple-ios27.0 SampleHandler.swift
plutil -lint Info.plist
```
