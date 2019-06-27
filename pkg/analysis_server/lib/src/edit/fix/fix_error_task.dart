// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/plugin/edit/fix/fix_core.dart';
import 'package:analysis_server/src/edit/edit_dartfix.dart';
import 'package:analysis_server/src/edit/fix/dartfix_listener.dart';
import 'package:analysis_server/src/edit/fix/dartfix_registrar.dart';
import 'package:analysis_server/src/services/correction/change_workspace.dart';
import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analysis_server/src/services/correction/fix_internal.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/error/codes.dart';

/// A task for fixing a particular error
class FixErrorTask {
  static void fixNamedConstructorTypeArgs(
      DartFixRegistrar registrar, DartFixListener listener) {
    registrar.registerErrorTask(
        StaticTypeWarningCode.WRONG_NUMBER_OF_TYPE_ARGUMENTS_CONSTRUCTOR,
        new FixErrorTask(listener));
  }

  final DartFixListener listener;

  FixErrorTask(this.listener);

  Future<void> fixError(ResolvedUnitResult result, AnalysisError error) async {
    final workspace = DartChangeWorkspace(listener.server.currentSessions);
    final dartContext = new DartFixContextImpl(
      workspace,
      result,
      error,
      (name) => [],
    );
    final processor = new FixProcessor(dartContext);
    Fix fix = await processor.computeFix();
    final location = listener.locationFor(result, error.offset, error.length);
    if (fix != null) {
      listener.addSourceChange(fix.change.message, location, fix.change);
    } else {
      // TODO(danrubel): Determine why the fix could not be applied
      // and report that in the description.
      listener.addRecommendation('Could not fix "${error.message}"', location);
    }
  }
}

/// A processor used by [EditDartFix] to manage [FixErrorTask]s.
mixin FixErrorProcessor {
  /// A mapping from [ErrorCode] to the fix that should be applied.
  final errorTaskMap = <ErrorCode, FixErrorTask>{};

  Future<bool> processErrors(ResolvedUnitResult result) async {
    bool foundError = false;
    for (AnalysisError error in result.errors) {
      final task = errorTaskMap[error.errorCode];
      if (task != null) {
        await task.fixError(result, error);
      } else if (error.errorCode.type == ErrorType.SYNTACTIC_ERROR) {
        foundError = true;
      }
    }
    return foundError;
  }

  Future<bool> fixError(ResolvedUnitResult result, AnalysisError error) async {
    return true;
  }

  void registerErrorTask(ErrorCode errorCode, FixErrorTask task) {
    errorTaskMap[errorCode] = task;
  }
}
