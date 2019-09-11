// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/error/hint_codes.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(IsNotDoubleTest);
  });
}

@reflectiveTest
class IsNotDoubleTest extends DriverResolutionTest {
  @override
  AnalysisOptionsImpl get analysisOptions =>
      AnalysisOptionsImpl()..dart2jsHint = true;

  test_use() async {
    await assertErrorsInCode('''
var v = 1 is! double;
''', [
      error(HintCode.IS_NOT_DOUBLE, 8, 12),
    ]);
  }
}
