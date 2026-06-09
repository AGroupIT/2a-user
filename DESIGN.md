# Design

## Source of truth
- Status: Active
- Last refreshed: 2026-06-08
- Primary product surfaces: `2a-user` mobile/web client cabinet, especially main home dashboard, tracks/assemblies, photo reports, and shell menus.
- Evidence reviewed:
  - `lib/src/features/home/presentation/home_screen.dart` — current dashboard content, stats, warehouse block, promo banner, digest tabs.
  - `lib/src/features/tracks/presentation/tracks_screen.dart` — tracks/assemblies archive, mode switch, filters/search/sort, bulk selection, track and assembly cards.
  - `lib/src/features/photos/presentation/photos_screen.dart` — photo reports archive, grouped photo grid, fullscreen viewer entrypoint, loading/error/empty states.
  - `lib/src/core/ui/app_colors.dart` — agent brand colors via `context.brandPrimary`, `context.brandSecondary`, neutral app background.
  - `lib/src/core/ui/app_layout.dart` — shared responsive breakpoints, shell obstruction metrics, content/modal max widths.
  - `lib/src/features/shell/presentation/app_shell.dart` — floating top bar, mobile bottom navigation, desktop side navigation.
  - `lib/src/app/widgets/app_scaffold.dart` — root-route scaffold and shared floating top menu constraints.
  - `lib/src/features/profile/data/profile_provider.dart` — agent banner/warehouse fields and active client context.

## Brand
- Personality: reliable logistics cabinet, clear, modern, confident, not playful.
- Trust signals: agent branding, client code visibility, warehouse copy actions, status clarity.
- Avoid: dense grids, tiny primary actions, low-contrast date/status metadata, decorative UI that hides operational actions.

## Product goals
- Goals: make the home screen a quick operational dashboard; help users add and manage tracks/assemblies, copy warehouse data, search no-code tracks, browse photo reports, and see latest changes in seconds.
- Non-goals: changing data contracts, removing existing content, adding new backend-dependent widgets without explicit need.
- Success signals: primary action is obvious, scan path is top-to-bottom, digest tabs are easy to tap, cards feel consistent and premium.

## Personas and jobs
- Primary personas: clients tracking parcels, invoices, assemblies, photo reports, and warehouse delivery details.
- User jobs: check current state, open profile from the identity block, add track numbers, filter/search/sort tracks and assemblies, copy warehouse address/phone, browse warehouse photo/video reports by date, find a track that is not yet linked to the client code, open latest item details.
- Key contexts of use: mobile-first, one-handed use, intermittent connectivity, returning users who need fast status checks.

## Information architecture
- Primary navigation: mobile and tablet portrait use bottom navigation; iPad landscape, macOS, and desktop web use a left side rail plus the same floating top menu. The `Ещё` entry opens a premium quick-action sheet, not a dense full-screen menu.
- Core routes/screens: home, tracks, invoices, photos, profile/more.
- Content hierarchy: floating shell navigation -> greeting/client identity -> primary action -> summary metrics -> optional promo/warehouse -> secondary no-code track search -> latest updates digest; tracks screen uses brand archive header -> view mode control -> compact action controls -> virtualized track/assembly list -> load/end state; photos screen uses brand archive header -> date groups -> virtualized photo grid -> load/end state; invoices screen uses brand archive header -> inline search/filter controls -> invoice cards focused on invoice number and USD amount -> detail sheet with summary, cargo, calculation, bonus, and media sections; client-code switcher adds per-code operational counters for quick account choice; More sheet groups secondary actions into quick actions, tools, account, materials, and diagnostics.

## Design principles
- Principle 1: operational clarity beats decoration; every prominent block should answer “what can I do now?”.
- Principle 2: one visual system per screen; cards, radii, shadows, and pills should feel related.
- Tradeoffs: keep existing backend/provider data and large `home_screen.dart` structure for a focused safe patch.

## Visual language
- Color: use dynamic agent brand colors for hero, primary action, selected states, and accents; neutral white cards on `#F2F2F7` background.
- Typography: Gilroy, bold for dashboard numbers and card titles; small semibold metadata for dates and weekly deltas.
- Spacing/layout rhythm: 8-14 px internal rhythm for dashboard density, 18-24 px radii on cards, larger tap targets than the old 24-30 px controls.
- Shape/radius/elevation: soft premium cards, subtle shadows, pill metadata/statuses, floating glass navigation with 18-24 px radii.
- Motion: light staggered reveal for dashboard blocks, subtle loop on the hero/primary CTA, softly animated hero backdrop circles clipped from card edges, animated active bottom-nav pill, `AnimatedSwitcher` for digest tab content; no heavy or blocking animations on home.
- Imagery/iconography: Material/Cupertino operational icons; icons support scanning but do not replace labels.

## Components
- Existing components to reuse: `AppToast`, `AppCachedMediaImage`, `EmptyState`, `TutorialScreenWrapper`, `AppLayout`, agent brand color extension.
- New/changed components: adaptive shell with mobile bottom navigation and desktop side rail, constrained root-route scaffold, constrained branded modal surface, home header card with clipped animated glow backdrop, primary add-track CTA, compact modern stat cards, warehouse action card, secondary no-code search card, digest card/tabs/items, premium tracks/assemblies header, mode switch, action controls, state cards and list cards, premium action bottom sheets for track/assembly tasks, premium invoices header/search/filter/card/detail sheet, premium profile header/hero/cards, premium notifications sheet/cards, premium support chat bubbles/composer/attachment sheet, premium photo reports archive header/date divider/thumbnail grid, premium floating top menu and bottom navigation, premium client-code switcher sheet with compact per-code stats, premium More quick-action sheet.
- Variants and states: loading/error/empty digest cards; selected/unselected digest tabs; tappable/non-tappable stat cards; tracks/assemblies loading skeleton, retry card, empty card, end-of-list pill, selected track card, status/action chips, raised bulk-selection action bar; photo reports loading skeleton, retry card, empty card, end-of-list pill, video thumbnail state; client-code stat chips show loading, count, and error placeholders.
- Token/component ownership: keep changes local to `home_screen.dart` unless a pattern is reused on 2+ screens.

## Accessibility
- Target standard: mobile readable contrast and 44 px-ish tap targets for core actions.
- Keyboard/focus behavior: keep current Flutter navigation behavior; no custom keyboard traps.
- Contrast/readability: avoid pale metadata on white; statuses use tinted pills with readable text.
- Screen-reader semantics: labels remain text-first; icons are supplemental.
- Reduced motion and sensory considerations: motion is short and non-essential.

## Responsive behavior
- Supported breakpoints/devices:
  - Mobile: `< 600px`, touch-first, one-column content, bottom navigation.
  - Tablet portrait: `600–1023px`, centered content up to ~760px, bottom navigation constrained to a comfortable width.
  - iPad landscape / desktop: `>= 1024px` or `>= 840px` when landscape, left side rail replaces bottom navigation, bottom obstruction is removed, content is centered.
  - Wide desktop/web/Mac: `>= 1440px`, content max width increases but operational cards never stretch edge-to-edge.
- Layout adaptations: shell pages are constrained through `AppLayout.constrainNavigationContent`; root routes through `AppScaffold` are constrained through `AppLayout.constrainContent`; stat grids/cards should use 2–4 columns only when the local content width supports it; digest tabs horizontally scroll instead of squeezing text; photo reports grid uses fewer larger columns on mobile and more columns on wider web; all modal sheets are constrained to tablet/desktop modal widths instead of spanning the whole monitor.
- Touch/hover differences: touch actions remain primary; desktop may show tooltips and hover/InkWell states but must not rely on hover-only controls. Side navigation labels are always visible enough to identify sections.

## Interaction states
- Loading: neutral rounded card with spinner or premium skeleton on list-heavy screens.
- Empty: neutral rounded card with concise empty copy and a clear next action when relevant.
- Error: neutral rounded card with red error text and retry action when data can be reloaded.
- Success: toast via existing `AppToast`.
- Disabled: existing Flutter disabled button treatment.
- Input fields: neutral outlined inputs must keep their rounded-corner border visible in the resting state; focused inputs switch to the agent brand border without changing the field shape.
- Search fields: secondary search inputs may hide the search icon on focus to reduce visual noise, but must add left text padding so typed text stays aligned inside the rounded frame.
- Home identity hero: tap opens the profile screen; the whole card is the tap target, not only the name text.
- More sheet: top quick actions should cover the most frequent jobs — profile, support, payment chat, and calculator; lower sections keep secondary tools discoverable without competing with primary actions.
- Photo reports header: keep the hero focused on the archive title and explanation; client code and total counters should not compete with photo/date content.
- Tracks/assemblies screen: preserve existing business logic and sliver virtualization; visual changes should align with the home/photo hero style, use one compact control card, keep search immediately available as an inline input, keep filter/sort/add as icon-only secondary actions, render dates like the home digest `icon + date` metadata instead of heavy pills, render notes/questions as premium nested cards instead of old grey utility blocks, open all action sheets through the root navigator so the floating bottom navigation is hidden behind the modal, keep track/assembly task modals including return requests on the shared branded sheet surface without duplicate bottom safe-area gaps, keep destructive/confirm primary actions visible in a fixed sheet footer when the body can scroll, keep filter reset/apply actions pinned in the sheet footer while only filter sections scroll, keep the create-assembly wizard header, step indicator, warning microcopy, and Back/Next actions pinned while only the current step content scrolls, style the delivery-method sheet as a branded modal with a pinned current-choice summary, selected method cards, explanatory notices, recipient fields grouped into cards, and fixed cancel/save actions, and keep the bulk-selection bar raised above the floating bottom navigation; repeated "Все" after selecting all tracks clears the selection.
- Invoices screen: hero stays focused on title/explanation without client-code or aggregate chips; cards must expose invoice number, compact track-style status, track-style created/updated dates, and the USD total first. Do not duplicate the open action as a button when the whole card opens the detail sheet; tracks/places/rub/yuan equivalents belong in the detail sheet, not on the list card. Invoice detail must be readable as logical blocks: summary, plain invoice facts without a separate "Как читать счёт" section header/icon, cargo/delivery, amount calculation, bonus kg, and photos/waybills. Waybill photos use the same small-thumbnail-to-fullscreen behavior as scale photos. Filter and detail sheets use the branded sheet surface with fixed footer actions separated from scroll content.
- Support chat screen: messages use soft premium bubbles with compact avatars and readable author/date metadata. The composer must be a slim floating pill separated from the bottom navigation, not a second heavy bottom bar; attachment/send buttons use brand rounded squares, pending attachments stay inside the composer, and the attachment picker uses the same branded sheet language as other modals. Sent image previews should preserve aspect ratio and fit inside a consistent preview area instead of being stretched or cropped awkwardly.
- Payment chat screen: visually follows support chat bubbles, composer, attachment picker, and image-preview behavior, but it is a root route without the floating bottom navigation; its composer should sit above the keyboard or bottom safe area only, not reserve space for the shell bottom bar. Payment-specific instruction copy stays as a compact premium info card near the page header.
- Notifications sheet: keep the modal focused on latest events, not filter management; do not show horizontal type filters unless product explicitly asks. Remove decorative emoji from notification titles, rely on type icons and compact type pills, use the branded header/surface/card language, and keep "mark all read" as an icon action in the header.
- Profile screen: unlike shell tabs, profile keeps an explicit in-content back button near the page title. The page should use a branded identity hero, soft 24px cards, compact info rows, and premium section headers while preserving existing edit, passkey, export, problem-report, and logout flows.
- Calculator screen: root utility pages should reuse the profile-style in-content header with explicit back button. The calculator uses a branded hero, soft 24px white cards, rounded outlined inputs/dropdowns with visible resting borders, assembly-style card selection for packaging, and a result card that exposes the USD total first, then a readable breakdown of tariff, delivery, unloading, packaging, and photo-report coefficient.
- Purchase blanks: root and detail pages reuse the profile/calculator-style in-content header with explicit back button. The flow should guide users through create blank -> add item links/photos/prices -> submit for review, with a focused hero, status filters, soft 24px cards, clear item cards/forms, rounded outlined inputs, thumbnail-first photos, and branded confirmation sheets preserving submit/cancel/delete flows.
- Joint purchases: root list, assembly detail, and track edit pages reuse the profile/calculator-style in-content header with explicit back button. The flow should make participant payment, track completeness, weight/shipping allocation, item totals, and profit easy to scan; use branded heroes, soft 24px cards, compact status pills, rounded outlined inputs, clear participant/track cards, and avoid double bottom safe-area gaps in any future SP modals.
- Home digest to tracks/assemblies: tapping a track or assembly from the home digest should navigate to the main tracks/assemblies screen, scroll to the real card in the list, and briefly highlight it; do not open a separate preview modal for tracks or assemblies because it duplicates context and can create large empty sheet space.
- Offline/slow network: stale data banner remains visible and actionable.

## Content voice
- Tone: concise, useful, operational.
- Terminology: use existing logistics terms: треки, сборки, счета, фото, склад, код клиента.
- Microcopy rules: prefer action verbs; avoid long explanations inside compact controls.

## Implementation constraints
- Framework/styling system: Flutter/Dart in `2a-user`; dynamic brand colors via theme/context.
- Design-token constraints: no new global design system unless reused elsewhere.
- Performance constraints: keep home digest lightweight; preserve `AppCachedMediaImage` for photos and keep photo archive on `CustomScrollView`/`SliverGrid` virtualization.
- Compatibility constraints: do not touch generated Dart files; preserve web/mobile behavior.
- Test/screenshot expectations: run `dart format`, `flutter analyze`, and visual smoke through Flutter web/mobile when possible.

## Open questions
- [ ] Should the home dashboard later expose unpaid invoice count or urgent statuses as a separate alert card? / owner: product / impact: prioritization.
- [ ] Should warehouse data be pinned above promo for every agent, or only when address/phone exists? / owner: product / impact: information hierarchy.
