{{flutter_js}}
{{flutter_build_config}}

(function() {
  function fail() {
    if (window.twoaWebStartup) window.twoaWebStartup.fail();
  }
  try {
    var canvasKitBase = new URL('canvaskit/', document.baseURI);
    if (canvasKitBase.origin !== window.location.origin) {
      canvasKitBase = new URL('/canvaskit/', window.location.origin);
    }
    var loading = _flutter.loader.load({
      config: { canvasKitBaseUrl: canvasKitBase.href },
      onEntrypointLoaded: async function(engineInitializer) {
        try {
          const appRunner = await engineInitializer.initializeEngine();
          await appRunner.runApp();
        } catch (error) {
          fail();
          throw error;
        }
      },
    });
    if (loading && typeof loading.catch === 'function') loading.catch(fail);
  } catch (_) {
    fail();
  }
})();
