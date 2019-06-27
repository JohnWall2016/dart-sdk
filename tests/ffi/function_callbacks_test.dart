// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Dart test program for testing dart:ffi function pointers with callbacks.
//
// SharedObjects=ffi_test_functions

library FfiTest;

import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'dylib_utils.dart';

import "package:expect/expect.dart";

typedef NativeCallbackTest = Int32 Function(Pointer);
typedef NativeCallbackTestFn = int Function(Pointer);

final DynamicLibrary testLibrary = dlopenPlatformSpecific("ffi_test_functions");

class Test {
  final String name;
  final Pointer callback;
  final bool skip;

  Test(this.name, this.callback, {bool skipIf: false}) : skip = skipIf {}

  void run() {
    if (skip) return;

    final NativeCallbackTestFn tester = testLibrary
        .lookupFunction<NativeCallbackTest, NativeCallbackTestFn>("Test$name");
    final int testCode = tester(callback);
    if (testCode != 0) {
      Expect.fail("Test $name failed.");
    }
  }
}

typedef SimpleAdditionType = Int32 Function(Int32, Int32);
int simpleAddition(int x, int y) => x + y;

typedef IntComputationType = Int64 Function(Int8, Int16, Int32, Int64);
int intComputation(int a, int b, int c, int d) => d - c + b - a;

typedef UintComputationType = Uint64 Function(Uint8, Uint16, Uint32, Uint64);
int uintComputation(int a, int b, int c, int d) => d - c + b - a;

typedef SimpleMultiplyType = Double Function(Double);
double simpleMultiply(double x) => x * 1.337;

typedef SimpleMultiplyFloatType = Float Function(Float);
double simpleMultiplyFloat(double x) => x * 1.337;

typedef ManyIntsType = IntPtr Function(IntPtr, IntPtr, IntPtr, IntPtr, IntPtr,
    IntPtr, IntPtr, IntPtr, IntPtr, IntPtr);
int manyInts(
    int a, int b, int c, int d, int e, int f, int g, int h, int i, int j) {
  return a + b + c + d + e + f + g + h + i + j;
}

typedef ManyDoublesType = Double Function(Double, Double, Double, Double,
    Double, Double, Double, Double, Double, Double);
double manyDoubles(double a, double b, double c, double d, double e, double f,
    double g, double h, double i, double j) {
  return a + b + c + d + e + f + g + h + i + j;
}

typedef ManyArgsType = Double Function(
    IntPtr,
    Float,
    IntPtr,
    Double,
    IntPtr,
    Float,
    IntPtr,
    Double,
    IntPtr,
    Float,
    IntPtr,
    Double,
    IntPtr,
    Float,
    IntPtr,
    Double,
    IntPtr,
    Float,
    IntPtr,
    Double);
double manyArgs(
    int _1,
    double _2,
    int _3,
    double _4,
    int _5,
    double _6,
    int _7,
    double _8,
    int _9,
    double _10,
    int _11,
    double _12,
    int _13,
    double _14,
    int _15,
    double _16,
    int _17,
    double _18,
    int _19,
    double _20) {
  return _1 +
      _2 +
      _3 +
      _4 +
      _5 +
      _6 +
      _7 +
      _8 +
      _9 +
      _10 +
      _11 +
      _12 +
      _13 +
      _14 +
      _15 +
      _16 +
      _17 +
      _18 +
      _19 +
      _20;
}

typedef StoreType = Pointer<Int64> Function(Pointer<Int64>);
Pointer<Int64> store(Pointer<Int64> ptr) => ptr.elementAt(1)..store(1337);

typedef NullPointersType = Pointer<Int64> Function(Pointer<Int64>);
Pointer<Int64> nullPointers(Pointer<Int64> ptr) => ptr?.elementAt(1);

typedef ReturnNullType = Int32 Function();
int returnNull() {
  print('Expect "unhandled exception" error message to follow.');
  return null;
}

typedef ReturnVoid = Void Function();
void returnVoid() {}

final List<Test> testcases = [
  Test("SimpleAddition", fromFunction<SimpleAdditionType>(simpleAddition)),
  Test("IntComputation", fromFunction<IntComputationType>(intComputation)),
  Test("UintComputation", fromFunction<UintComputationType>(uintComputation)),
  Test("SimpleMultiply", fromFunction<SimpleMultiplyType>(simpleMultiply)),
  Test("SimpleMultiplyFloat",
      fromFunction<SimpleMultiplyFloatType>(simpleMultiplyFloat)),
  Test("ManyInts", fromFunction<ManyIntsType>(manyInts)),
  Test("ManyDoubles", fromFunction<ManyDoublesType>(manyDoubles)),
  Test("ManyArgs", fromFunction<ManyArgsType>(manyArgs)),
  Test("Store", fromFunction<StoreType>(store)),
  Test("NullPointers", fromFunction<NullPointersType>(nullPointers)),
  Test("ReturnNull", fromFunction<ReturnNullType>(returnNull)),
];

testCallbackWrongThread() =>
    Test("CallbackWrongThread", fromFunction<ReturnVoid>(returnVoid)).run();

testCallbackOutsideIsolate() =>
    Test("CallbackOutsideIsolate", fromFunction<ReturnVoid>(returnVoid)).run();

isolateHelper(int callbackPointer) {
  final Pointer<Void> ptr = fromAddress(callbackPointer);
  final NativeCallbackTestFn tester =
      testLibrary.lookupFunction<NativeCallbackTest, NativeCallbackTestFn>(
          "TestCallbackWrongIsolate");
  Expect.equals(0, tester(ptr));
}

testCallbackWrongIsolate() async {
  final int callbackPointer = fromFunction<ReturnVoid>(returnVoid).address;
  final ReceivePort exitPort = ReceivePort();
  await Isolate.spawn(isolateHelper, callbackPointer,
      errorsAreFatal: true, onExit: exitPort.sendPort);
  await exitPort.first;
}

void main() async {
  testcases.forEach((t) => t.run()); //# 00: ok

  // These tests terminate the process after successful completion, so we have
  // to run them separately.
  //
  // Since they use signal handlers they only run on Linux.
  if (Platform.isLinux && !const bool.fromEnvironment("dart.vm.product")) {
    testCallbackWrongThread(); //# 01: ok
    testCallbackOutsideIsolate(); //# 02: ok
    await testCallbackWrongIsolate(); //# 03: ok
  }
}
