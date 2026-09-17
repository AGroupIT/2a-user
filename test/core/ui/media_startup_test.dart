import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_config.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_cached_media_image.dart';
import 'package:twoalogisticcabineuser/src/core/ui/startup_screen.dart';

void main() {
  testWidgets('thumbnail falls back once to original with caller options', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
    const url = '/uploads/tracks/wide.png';
    final widget = AppCachedMediaImage(
      url: url,
      fit: BoxFit.contain,
      memCacheWidth: 320,
      errorWidget: (_, _, _) => const Text('final error'),
    );
    final thumb = widget.build(context) as CachedNetworkImage;
    expect(thumb.imageUrl, contains('/preview/360/'));
    final original =
        thumb.errorWidget!(context, thumb.imageUrl, Exception())
            as CachedNetworkImage;
    expect(original.imageUrl, ApiConfig.getMediaUrl(url));
    expect(original.fit, BoxFit.contain);
    expect(original.memCacheWidth, 320);
    final error = original.errorWidget!(
      context,
      original.imageUrl,
      Exception(),
    );
    expect((error as Text).data, 'final error');
    final full =
        const AppCachedMediaImage(
              url: url,
              variant: AppMediaImageVariant.full,
            ).build(context)
            as CachedNetworkImage;
    expect(full.imageUrl, original.imageUrl);
    expect(ApiConfig.getMediaThumbnailUrl(url), isNot(contains('fit=')));
  });

  testWidgets('startup displays progress then recoverable retry state', (
    tester,
  ) async {
    await tester.pumpWidget(const StartupScreen());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    var retries = 0;
    await tester.pumpWidget(StartupScreen(onRetry: () => retries++));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byType(FilledButton));
    expect(retries, 1);
  });
}
