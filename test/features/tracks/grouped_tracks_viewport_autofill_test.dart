import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/tracks_screen.dart';

void main() {
  group('grouped tracks viewport autofill', () {
    test('loads another page when grouped cards do not fill the viewport', () {
      expect(
        shouldAutofillGroupedTracksViewport(
          isGroupedMode: true,
          hasMore: true,
          isLoading: false,
          hasError: false,
          hasScrollClients: true,
          maxScrollExtent: 0,
        ),
        isTrue,
      );
    });

    test('stops as soon as normal pagination can take over', () {
      expect(
        shouldAutofillGroupedTracksViewport(
          isGroupedMode: true,
          hasMore: true,
          isLoading: false,
          hasError: false,
          hasScrollClients: true,
          maxScrollExtent: 24,
        ),
        isFalse,
      );
    });

    test('does not load in invalid pagination states', () {
      bool shouldAutofill({
        bool isGroupedMode = true,
        bool hasMore = true,
        bool isLoading = false,
        bool hasError = false,
        bool hasScrollClients = true,
      }) {
        return shouldAutofillGroupedTracksViewport(
          isGroupedMode: isGroupedMode,
          hasMore: hasMore,
          isLoading: isLoading,
          hasError: hasError,
          hasScrollClients: hasScrollClients,
          maxScrollExtent: 0,
        );
      }

      expect(shouldAutofill(isGroupedMode: false), isFalse);
      expect(shouldAutofill(hasMore: false), isFalse);
      expect(shouldAutofill(isLoading: true), isFalse);
      expect(shouldAutofill(hasError: true), isFalse);
      expect(shouldAutofill(hasScrollClients: false), isFalse);
    });
  });
}
