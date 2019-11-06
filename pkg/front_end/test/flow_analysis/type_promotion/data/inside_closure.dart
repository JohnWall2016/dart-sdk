// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

void nested_closures(Function([dynamic]) f) {
  void inner(Object x) {
    if (x is String) {
      f();
      // TODO(paulberry): x should be promoted here.
      // See https://github.com/dart-lang/sdk/issues/38791
      x;
    }
    f(() {
      if (x is String) {
        f();
        x;
      }
      x = 0;
    });
    if (x is String) {
      f();
      x;
    }
  }
}
