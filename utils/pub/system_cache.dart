// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library system_cache;

import 'dart:io';

import 'io.dart';
import 'io.dart' as io show createTempDir;
import 'package.dart';
import 'source.dart';
import 'source_registry.dart';
import 'utils.dart';
import 'version.dart';

/**
 * The system-wide cache of installed packages.
 *
 * This cache contains all packages that are downloaded from the internet.
 * Packages that are available locally (e.g. from the SDK) don't use this cache.
 */
class SystemCache {
  /**
   * The root directory where this package cache is located.
   */
  final String rootDir;

  String get tempDir => join(rootDir, '_temp');

  /**
   * Packages which are currently being asynchronously installed to the cache.
   */
  final Map<PackageId, Future<Package>> _pendingInstalls;

  /**
   * The sources from which to install packages.
   */
  final SourceRegistry sources;

  /**
   * Creates a new package cache which is backed by the given directory on the
   * user's file system.
   */
  SystemCache(this.rootDir)
  : _pendingInstalls = new Map<PackageId, Future<Package>>(),
    sources = new SourceRegistry();

  /**
   * Registers a new source. This source must not have the same name as a source
   * that's already been registered.
   */
  void register(Source source) {
    source.bind(this);
    sources.register(source);
  }

  /**
   * Ensures that the package identified by [id] is installed to the cache,
   * loads it, and returns it.
   *
   * It is an error to try installing a package from a source with `shouldCache
   * == false` to the system cache.
   */
  Future<Package> install(PackageId id) {
    if (!id.source.shouldCache) {
      throw new ArgumentError("Package $id is not cacheable.");
    }

    var pending = _pendingInstalls[id];
    if (pending != null) return pending;

    var future = id.source.installToSystemCache(id);
    always(future, () => _pendingInstalls.remove(id));
    _pendingInstalls[id] = future;
    return future;
  }

  /// Create a new temporary directory within the system cache. The system
  /// cache maintains its own temporary directory that it uses to stage
  /// packages into while installing. It uses this instead of the OS's system
  /// temp directory to ensure that it's on the same volume as the pub system
  /// cache so that it can move the directory from it.
  Future<Directory> createTempDir() {
    return ensureDir(tempDir).chain((temp) {
      return io.createTempDir(join(temp, 'dir'));
    });
  }

  /// Delete's the system cache's internal temp directory.
  Future deleteTempDir() {
    return dirExists(tempDir).chain((exists) {
      if (!exists) return new Future.immediate(null);
      return deleteDir(tempDir);
    });
  }
}
