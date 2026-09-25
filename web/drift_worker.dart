// Compiles to web/drift_worker.js via `dart compile js`. Source mirrors
// the `drift` package's own bundled entrypoint (package:drift/web/
// drift_worker.dart) so this project's own package resolution (pinned
// drift version) is used when compiling, rather than the pub-cache
// package's own (unresolved) context. Regenerate the .js output whenever
// the pinned `drift` version changes.
import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}
