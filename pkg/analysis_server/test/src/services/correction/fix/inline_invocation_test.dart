// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analysis_server/src/services/linter/lint_names.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_processor.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(InlineInvocationTest);
  });
}

@reflectiveTest
class InlineInvocationTest extends FixProcessorLintTest {
  @override
  FixKind get kind => DartFixKind.INLINE_INVOCATION;

  @override
  String get lintCode => LintNames.prefer_inlined_adds;

  /// More coverage in the `inline_invocation_test.dart` assist test.
  test_add_emptyTarget() async {
    await resolveTestUnit('''
var l = []../*LINT*/add('a')..add('b');
''');
    await assertHasFix('''
var l = ['a']..add('b');
''');
  }
}
