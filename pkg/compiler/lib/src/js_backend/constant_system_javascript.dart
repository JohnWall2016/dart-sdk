// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js.constant_system.js;

import '../compiler.dart' show Compiler;
import '../constants/constant_system.dart';
import '../constants/values.dart';
import '../constant_system_dart.dart';
import '../core_types.dart' show CoreTypes;
import '../dart_types.dart';
import '../elements/elements.dart' show ClassElement, FieldElement;
import '../tree/tree.dart' show DartString, LiteralDartString;
import 'js_backend.dart';

const JAVA_SCRIPT_CONSTANT_SYSTEM = const JavaScriptConstantSystem();

class JavaScriptBitNotOperation extends BitNotOperation {
  const JavaScriptBitNotOperation();

  ConstantValue fold(ConstantValue constant) {
    if (JAVA_SCRIPT_CONSTANT_SYSTEM.isInt(constant)) {
      // In JavaScript we don't check for -0 and treat it as if it was zero.
      if (constant.isMinusZero) constant = DART_CONSTANT_SYSTEM.createInt(0);
      IntConstantValue intConstant = constant;
      // We convert the result of bit-operations to 32 bit unsigned integers.
      return JAVA_SCRIPT_CONSTANT_SYSTEM
          .createInt32(~intConstant.primitiveValue);
    }
    return null;
  }
}

/**
 * In JavaScript we truncate the result to an unsigned 32 bit integer. Also, -0
 * is treated as if it was the integer 0.
 */
class JavaScriptBinaryBitOperation implements BinaryOperation {
  final BinaryBitOperation dartBitOperation;

  const JavaScriptBinaryBitOperation(this.dartBitOperation);

  String get name => dartBitOperation.name;

  ConstantValue fold(ConstantValue left, ConstantValue right) {
    // In JavaScript we don't check for -0 and treat it as if it was zero.
    if (left.isMinusZero) left = DART_CONSTANT_SYSTEM.createInt(0);
    if (right.isMinusZero) right = DART_CONSTANT_SYSTEM.createInt(0);
    IntConstantValue result = dartBitOperation.fold(left, right);
    if (result != null) {
      // We convert the result of bit-operations to 32 bit unsigned integers.
      return JAVA_SCRIPT_CONSTANT_SYSTEM.createInt32(result.primitiveValue);
    }
    return result;
  }

  apply(left, right) => dartBitOperation.apply(left, right);
}

class JavaScriptShiftRightOperation extends JavaScriptBinaryBitOperation {
  const JavaScriptShiftRightOperation() : super(const ShiftRightOperation());

  ConstantValue fold(ConstantValue left, ConstantValue right) {
    // Truncate the input value to 32 bits if necessary.
    if (left.isInt) {
      IntConstantValue intConstant = left;
      int value = intConstant.primitiveValue;
      int truncatedValue = value & JAVA_SCRIPT_CONSTANT_SYSTEM.BITS32;
      if (value < 0) {
        // Sign-extend if the input was negative. The current semantics don't
        // make much sense, since we only look at bit 31.
        // TODO(floitsch): we should treat the input to right shifts as
        // unsigned.

        // A 32 bit complement-two value x can be computed by:
        //    x_u - 2^32 (where x_u is its unsigned representation).
        // Example: 0xFFFFFFFF - 0x100000000 => -1.
        // We simply and with the sign-bit and multiply by two. If the sign-bit
        // was set, then the result is 0. Otherwise it will become 2^32.
        final int SIGN_BIT = 0x80000000;
        truncatedValue -= 2 * (truncatedValue & SIGN_BIT);
      }
      if (value != truncatedValue) {
        left = DART_CONSTANT_SYSTEM.createInt(truncatedValue);
      }
    }
    return super.fold(left, right);
  }
}

class JavaScriptNegateOperation implements UnaryOperation {
  final NegateOperation dartNegateOperation = const NegateOperation();

  const JavaScriptNegateOperation();

  String get name => dartNegateOperation.name;

  ConstantValue fold(ConstantValue constant) {
    if (constant.isInt) {
      IntConstantValue intConstant = constant;
      if (intConstant.primitiveValue == 0) {
        return JAVA_SCRIPT_CONSTANT_SYSTEM.createDouble(-0.0);
      }
    }
    return dartNegateOperation.fold(constant);
  }
}

class JavaScriptAddOperation implements BinaryOperation {
  final _addOperation = const AddOperation();
  String get name => _addOperation.name;

  const JavaScriptAddOperation();

  ConstantValue fold(ConstantValue left, ConstantValue right) {
    ConstantValue result = _addOperation.fold(left, right);
    if (result != null && result.isNum) {
      return JAVA_SCRIPT_CONSTANT_SYSTEM.convertToJavaScriptConstant(result);
    }
    return result;
  }

  apply(left, right) => _addOperation.apply(left, right);
}

class JavaScriptBinaryArithmeticOperation implements BinaryOperation {
  final BinaryOperation dartArithmeticOperation;

  const JavaScriptBinaryArithmeticOperation(this.dartArithmeticOperation);

  String get name => dartArithmeticOperation.name;

  ConstantValue fold(ConstantValue left, ConstantValue right) {
    ConstantValue result = dartArithmeticOperation.fold(left, right);
    if (result == null) return result;
    return JAVA_SCRIPT_CONSTANT_SYSTEM.convertToJavaScriptConstant(result);
  }

  apply(left, right) => dartArithmeticOperation.apply(left, right);
}

class JavaScriptIdentityOperation implements BinaryOperation {
  final IdentityOperation dartIdentityOperation = const IdentityOperation();

  const JavaScriptIdentityOperation();

  String get name => dartIdentityOperation.name;

  BoolConstantValue fold(ConstantValue left, ConstantValue right) {
    BoolConstantValue result = dartIdentityOperation.fold(left, right);
    if (result == null || result.primitiveValue) return result;
    // In JavaScript -0.0 === 0 and all doubles are equal to their integer
    // values. Furthermore NaN !== NaN.
    if (left.isNum && right.isNum) {
      NumConstantValue leftNum = left;
      NumConstantValue rightNum = right;
      double leftDouble = leftNum.primitiveValue.toDouble();
      double rightDouble = rightNum.primitiveValue.toDouble();
      return new BoolConstantValue(leftDouble == rightDouble);
    }
    return result;
  }

  apply(left, right) => identical(left, right);
}

/**
 * Constant system following the semantics for Dart code that has been
 * compiled to JavaScript.
 */
class JavaScriptConstantSystem extends ConstantSystem {
  final int BITS31 = 0x8FFFFFFF;
  final int BITS32 = 0xFFFFFFFF;

  final add = const JavaScriptAddOperation();
  final bitAnd = const JavaScriptBinaryBitOperation(const BitAndOperation());
  final bitNot = const JavaScriptBitNotOperation();
  final bitOr = const JavaScriptBinaryBitOperation(const BitOrOperation());
  final bitXor = const JavaScriptBinaryBitOperation(const BitXorOperation());
  final booleanAnd = const BooleanAndOperation();
  final booleanOr = const BooleanOrOperation();
  final divide =
      const JavaScriptBinaryArithmeticOperation(const DivideOperation());
  final equal = const EqualsOperation();
  final greaterEqual = const GreaterEqualOperation();
  final greater = const GreaterOperation();
  final identity = const JavaScriptIdentityOperation();
  final ifNull = const IfNullOperation();
  final lessEqual = const LessEqualOperation();
  final less = const LessOperation();
  final modulo =
      const JavaScriptBinaryArithmeticOperation(const ModuloOperation());
  final multiply =
      const JavaScriptBinaryArithmeticOperation(const MultiplyOperation());
  final negate = const JavaScriptNegateOperation();
  final not = const NotOperation();
  final shiftLeft =
      const JavaScriptBinaryBitOperation(const ShiftLeftOperation());
  final shiftRight = const JavaScriptShiftRightOperation();
  final subtract =
      const JavaScriptBinaryArithmeticOperation(const SubtractOperation());
  final truncatingDivide = const JavaScriptBinaryArithmeticOperation(
      const TruncatingDivideOperation());
  final codeUnitAt = const CodeUnitAtRuntimeOperation();

  const JavaScriptConstantSystem();

  /**
   * Returns true if [value] will turn into NaN or infinity
   * at runtime.
   */
  bool integerBecomesNanOrInfinity(int value) {
    double doubleValue = value.toDouble();
    return doubleValue.isNaN || doubleValue.isInfinite;
  }

  NumConstantValue convertToJavaScriptConstant(NumConstantValue constant) {
    if (constant.isInt) {
      IntConstantValue intConstant = constant;
      int intValue = intConstant.primitiveValue;
      if (integerBecomesNanOrInfinity(intValue)) {
        return new DoubleConstantValue(intValue.toDouble());
      }
      // If the integer loses precision with JavaScript numbers, use
      // the floored version JavaScript will use.
      int floorValue = intValue.toDouble().floor().toInt();
      if (floorValue != intValue) {
        return new IntConstantValue(floorValue);
      }
    } else if (constant.isDouble) {
      DoubleConstantValue doubleResult = constant;
      double doubleValue = doubleResult.primitiveValue;
      if (!doubleValue.isInfinite &&
          !doubleValue.isNaN &&
          !constant.isMinusZero) {
        int intValue = doubleValue.truncate();
        if (intValue == doubleValue) {
          return new IntConstantValue(intValue);
        }
      }
    }
    return constant;
  }

  @override
  NumConstantValue createInt(int i) {
    return convertToJavaScriptConstant(new IntConstantValue(i));
  }

  NumConstantValue createInt32(int i) => new IntConstantValue(i & BITS32);
  NumConstantValue createDouble(double d) =>
      convertToJavaScriptConstant(new DoubleConstantValue(d));
  StringConstantValue createString(DartString string) {
    return new StringConstantValue(string);
  }

  BoolConstantValue createBool(bool value) => new BoolConstantValue(value);
  NullConstantValue createNull() => new NullConstantValue();

  @override
  ListConstantValue createList(InterfaceType type, List<ConstantValue> values) {
    return new ListConstantValue(type, values);
  }

  @override
  ConstantValue createType(Compiler compiler, DartType type) {
    return new TypeConstantValue(type,
        compiler.backend.typeImplementation.computeType(compiler.resolution));
  }

  // Integer checks report true for -0.0, INFINITY, and -INFINITY.  At
  // runtime an 'X is int' check is implemented as:
  //
  // typeof(X) === "number" && Math.floor(X) === X
  //
  // We consistently match that runtime semantics at compile time as well.
  bool isInt(ConstantValue constant) {
    return constant.isInt ||
        constant.isMinusZero ||
        constant.isPositiveInfinity ||
        constant.isNegativeInfinity;
  }

  bool isDouble(ConstantValue constant) =>
      constant.isDouble && !constant.isMinusZero;
  bool isString(ConstantValue constant) => constant.isString;
  bool isBool(ConstantValue constant) => constant.isBool;
  bool isNull(ConstantValue constant) => constant.isNull;

  bool isSubtype(DartTypes types, DartType s, DartType t) {
    // At runtime, an integer is both an integer and a double: the
    // integer type check is Math.floor, which will return true only
    // for real integers, and our double type check is 'typeof number'
    // which will return true for both integers and doubles.
    if (s == types.coreTypes.intType && t == types.coreTypes.doubleType) {
      return true;
    }
    return types.isSubtype(s, t);
  }

  MapConstantValue createMap(Compiler compiler, InterfaceType sourceType,
      List<ConstantValue> keys, List<ConstantValue> values) {
    JavaScriptBackend backend = compiler.backend;
    CoreTypes coreTypes = compiler.coreTypes;

    bool onlyStringKeys = true;
    ConstantValue protoValue = null;
    for (int i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (key.isString) {
        if (key.primitiveValue == JavaScriptMapConstant.PROTO_PROPERTY) {
          protoValue = values[i];
        }
      } else {
        onlyStringKeys = false;
        // Don't handle __proto__ values specially in the general map case.
        protoValue = null;
        break;
      }
    }

    bool hasProtoKey = (protoValue != null);
    DartType keysType;
    if (sourceType.treatAsRaw) {
      keysType = coreTypes.listType();
    } else {
      keysType = coreTypes.listType(sourceType.typeArguments.first);
    }
    ListConstantValue keysList = new ListConstantValue(keysType, keys);
    String className = onlyStringKeys
        ? (hasProtoKey
            ? JavaScriptMapConstant.DART_PROTO_CLASS
            : JavaScriptMapConstant.DART_STRING_CLASS)
        : JavaScriptMapConstant.DART_GENERAL_CLASS;
    ClassElement classElement = backend.helpers.jsHelperLibrary.find(className);
    classElement.ensureResolved(compiler.resolution);
    List<DartType> typeArgument = sourceType.typeArguments;
    InterfaceType type;
    if (sourceType.treatAsRaw) {
      type = classElement.rawType;
    } else {
      type = new InterfaceType(classElement, typeArgument);
    }
    return new JavaScriptMapConstant(
        type, keysList, values, protoValue, onlyStringKeys);
  }

  @override
  ConstantValue createSymbol(Compiler compiler, String text) {
    // TODO(johnniwinther): Create a backend agnostic value.
    InterfaceType type = compiler.coreTypes.symbolType;
    ConstantValue argument = createString(new DartString.literal(text));
    Map<FieldElement, ConstantValue> fields = <FieldElement, ConstantValue>{};
    JavaScriptBackend backend = compiler.backend;
    backend.helpers.symbolImplementationClass.forEachInstanceField(
        (ClassElement enclosingClass, FieldElement field) {
      fields[field] = argument;
    });
    assert(fields.length == 1);
    return new ConstructedConstantValue(type, fields);
  }
}

class JavaScriptMapConstant extends MapConstantValue {
  /**
   * The [PROTO_PROPERTY] must not be used as normal property in any JavaScript
   * object. It would change the prototype chain.
   */
  static const LiteralDartString PROTO_PROPERTY =
      const LiteralDartString("__proto__");

  /** The dart class implementing constant map literals. */
  static const String DART_CLASS = "ConstantMap";
  static const String DART_STRING_CLASS = "ConstantStringMap";
  static const String DART_PROTO_CLASS = "ConstantProtoMap";
  static const String DART_GENERAL_CLASS = "GeneralConstantMap";
  static const String LENGTH_NAME = "_length";
  static const String JS_OBJECT_NAME = "_jsObject";
  static const String KEYS_NAME = "_keys";
  static const String PROTO_VALUE = "_protoValue";
  static const String JS_DATA_NAME = "_jsData";

  final ListConstantValue keyList;
  final ConstantValue protoValue;
  final bool onlyStringKeys;

  JavaScriptMapConstant(InterfaceType type, ListConstantValue keyList,
      List<ConstantValue> values, this.protoValue, this.onlyStringKeys)
      : this.keyList = keyList,
        super(type, keyList.entries, values);
  bool get isMap => true;

  List<ConstantValue> getDependencies() {
    List<ConstantValue> result = <ConstantValue>[];
    if (onlyStringKeys) {
      result.add(keyList);
    } else {
      // Add the keys individually to avoid generating an unused list constant
      // for the keys.
      result.addAll(keys);
    }
    result.addAll(values);
    return result;
  }
}
