//===- BtorOps.td - Btor dialect ops -----------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef BTOR_OPS
#define BTOR_OPS

include "BtorBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/IR/OpAsmInterface.td"
include "mlir/Interfaces/CastInterfaces.td"
include "mlir/Interfaces/VectorInterfaces.td"
include "mlir/IR/BuiltinAttributes.td"
include "Dialect/Btor/IR/BtorTypes.td"
include "Dialect/Btor/IR/BtorAttributes.td"

//===----------------------------------------------------------------------===//
// Base btor operation definition.
//===----------------------------------------------------------------------===//

class Btor_Op<string mnemonic, list<Trait> traits = []>
    : Op<Btor_Dialect, mnemonic, traits>;

//===----------------------------------------------------------------------===//
// btor integer bit cast ops definitions
//===----------------------------------------------------------------------===//

// Base class for Btor Cast operations Requires a single operand and result.
class Btor_CastOp<string mnemonic, TypeConstraint From, TypeConstraint To,
                  list<Trait> traits = []>
    : Btor_Op<mnemonic, traits #[SameOperandsAndResultShape]>,
      Arguments<(ins From
                 : $in)>,
      Results<(outs To
               : $out)> {
  let assemblyFormat = "$in attr-dict `:` type($in) `to` type($out)";
}

// Cast from an integer type to another integer type.
class BtorCastOp<string mnemonic>
    : Btor_CastOp<mnemonic, Btor_BitVec, Btor_BitVec> {
  let builders = [OpBuilder<(ins "Value"
                             : $in, "Type"
                             : $type),
                            [{ build($_builder, $_state, type, in); }]>];
}

def UExtOp : BtorCastOp<"uext"> {
  let summary = "integer zero extension operation";
  // clang-format off
  let description = [{
    The integer zero extension operation takes an integer input of
    width M and an integer destination type of width N.
    The destination bit minus width must be larger than the input bit
    minus width(N > M). The top minus most(N - M) bits of the output 
    are filled with zeros.

    Example:

    ```mlir 
    %2 = btor.uext %1: !bv<3> to !bv<9>
    ```
  }];
  let verifier = [{ return verifyExtOp<btor::BitVecType>(*this); }];
  // clang-format on
}

def SExtOp : BtorCastOp<"sext"> {
  let summary = "integer zero extension operation";
  // clang-format off
  let description = [{
    The integer zero extension operation takes an integer input of
    width M and an integer destination type of width N.
    The destination bit minus width must be larger than the input bit
    minus width(N > M). The top minus most(N - M) bits of the output
    are filled with copies of the most significant bit.
    
    Example:

    ```mlir 
    %2 = btor.sext %1: !bv<3> to !bv<9>
    ```
  }];
  let verifier = [{ return verifyExtOp<btor::BitVecType>(*this); }];
  // clang-format on
}

//===----------------------------------------------------------------------===//
// btor ternary integer ops definitions
//===----------------------------------------------------------------------===//

def IteOp : Btor_Op<"ite", [
  NoSideEffect, AllTypesMatch<["true_value", "false_value", "result"]>
] #ElementwiseMappable.traits> {
  let summary = "integer if-then-else operation";
  // clang-format off
  let description = [{
    This operation takes a condition and two integer arguments and
    returns an integer.

    Example:
          
    ```mlir
    %res = btor.ite %cond, %true, %false: !bv<32>
    ```
  }];

  let arguments = (ins Btor_BitVec: $condition,
                  AnyType: $true_value,
                  AnyType: $false_value);
  let results = (outs AnyType : $result);
  let extraClassDeclaration = [{
    Value getCondition() { return condition(); }
    Value getTrueValue() { return true_value(); }
    Value getFalseValue() { return false_value(); }
  }];

  let parser = [{ return parseIteOp(parser, result); }];
  let printer = [{ return printIteOp(p, this); }];
// clang-format on
}

def SliceOp : Btor_Op<"slice", [
  NoSideEffect,
  AllTypesMatch<["upper_bound", "lower_bound"]>
] #ElementwiseMappable.traits> {

  let summary = "integer slice operation";
  // clang-format off
  let description = [{
    This operation takes an input of size N and two integer arguments,
    U and L, and returns an integer of size: U - L + 1, where L <= U < N.

    Example:
        
    ```mlir
    %res = btor.slice %in, %upper, %lower: iN, i(upper - lower + 1)
    ```
  }];

  let arguments = (ins Btor_BitVec: $in,
                   Btor_BitVec: $upper_bound,
                   Btor_BitVec: $lower_bound);
  let results = (outs Btor_BitVec : $result);

  let builders =
      [OpBuilder<(ins "Value": $in,
                  "Value": $upper_bound,
                  "Value": $lower_bound),
      [{
        $_state.addOperands({in, upper_bound, lower_bound});
      }]>];
  let parser = [{ return parseSliceOp(parser, result); }];
  let printer = [{ return printSliceOp(p, this->getOperation()); }];
  let verifier = [{ return verifySliceOp<btor::BitVecType>(*this); }];
  // clang-format on
}

//===----------------------------------------------------------------------===//
// btor binary integer ops definitions
//===----------------------------------------------------------------------===//

// Base class for btor arithmetic operations.  Requires operands and
// results to be of the same type, but does not constrain them to specific
// types.
class BtorArithmeticOp<string mnemonic, list<Trait> traits = []>
    : Op<Btor_Dialect, mnemonic, traits>;

// This operation takes two operands and returns one result,
// each of these is required to be of the same type.
//  The custom assembly form of the operation is as follows
//
//     <op> %0, %1 : !bv<32>
// clang-format off
class BtorBinaryOp<string mnemonic, list<Trait> traits = []>
  : BtorArithmeticOp<mnemonic,
                      !listconcat(traits, [SameOperandsAndResultType])>,
    Arguments<(ins Btor_BitVec: $lhs, 
                Btor_BitVec: $rhs)>,
    Results<(outs Btor_BitVec: $result)> {
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` qualified(type($result))";
  // clang-format on
}

// This operation takes two operands or the same type
// and returns one result of type !bv<1>
//
//     <op> %0, %1 : !bv<1>
// clang-format off
class BtorBinaryDifferentResultTypeOp<string mnemonic, list<Trait> traits = []>
    : BtorArithmeticOp<mnemonic, traits>,
      Arguments<(ins Btor_BitVec: $lhs, Btor_BitVec: $rhs)> {

  let results = (outs Btor_BitVec : $result);
  let parser = [{ return parseBinaryOverflowOp(parser, result); }];
  let printer = [{ return printBinaryOverflowOp(p, this->getOperation()); }];
  // clang-format on
}

def AddOp : BtorBinaryOp<"add", [Commutative]> {
  let summary = "integer addition operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.add %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def SAddOverflowOp : BtorBinaryDifferentResultTypeOp<"saddo", [Commutative]> {
  let summary = "signed integer addition with overflow flag";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.saddo %lhs, %rhs: !bv<1>
    ```
  }];
  // clang-format on
}

def UAddOverflowOp : BtorBinaryDifferentResultTypeOp<"uaddo", [Commutative]> {
  let summary = "unsigned integer addition with overflow flag";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.uaddo %lhs, %rhs: !bv<1>
    ```
  }];
  // clang-format on
}

def SubOp : BtorBinaryOp<"sub"> {
  let summary = "integer subtraction operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.sub %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def SSubOverflowOp : BtorBinaryDifferentResultTypeOp<"ssubo"> {
  let summary = "signed integer subtraction with overflow flag";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.ssubo %lhs, %rhs: !bv<1>
        ```
  }];
  // clang-format on
}

def USubOverflowOp : BtorBinaryDifferentResultTypeOp<"usubo"> {
  let summary = "unsigned integer subtraction with overflow flag";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.usubo %lhs, %rhs: !bv<1>
    ```
  }];
  // clang-format on
}

def MulOp : BtorBinaryOp<"mul", [Commutative]> {
  let summary = "integer multiplication operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.mul %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def SMulOverflowOp : BtorBinaryDifferentResultTypeOp<"smulo"> {
  let summary = "signed integer multiplication with overflow flag";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.smulo %lhs, %rhs: !bv<1>
    ```
  }];
  // clang-format on
}

def UMulOverflowOp : BtorBinaryDifferentResultTypeOp<"umulo"> {
  let summary = "unsigned integer multiplication with overflow flag";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.umulo %lhs, %rhs: !bv<1>
    ```
  }];
  // clang-format on
}

def SModOp : BtorBinaryOp<"smod"> {
  let summary = "integer signed modulus operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.smod %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def SRemOp : BtorBinaryOp<"srem"> {
  let summary = "integer signed remainder operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.srem %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def URemOp : BtorBinaryOp<"urem"> {
  let summary = "integer unsigned remainder operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.urem %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def SDivOp : BtorBinaryOp<"sdiv"> {
  let summary = "integer signed division operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.sdiv %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def SDivOverflowOp : BtorBinaryDifferentResultTypeOp<"sdivo"> {
  let summary = "signed integer division with overflow flag";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.sdivo %lhs, %rhs: !bv<1>
    ```
  }];
  // clang-format on
}

def UDivOp : BtorBinaryOp<"udiv"> {
  let summary = "integer unsigned division operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.udiv %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def OrOp : BtorBinaryOp<"or", [Commutative]> {
  let summary = "integer binary and operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.or %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def NorOp : BtorBinaryOp<"nor", [Commutative]> {
  let summary = "integer binary nor operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.nor %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def AndOp : BtorBinaryOp<"and", [Commutative]> {
  let summary = "integer binary and operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.and %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def NandOp : BtorBinaryOp<"nand", [Commutative]> {
  let summary = "integer binary nand operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.nand %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def XOrOp : BtorBinaryOp<"xor", [Commutative]> {
  let summary = "integer binary xor operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.xor %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def XnorOp : BtorBinaryOp<"xnor", [Commutative]> {
  let summary = "integer binary xnor operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.xnor %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def CmpOp : Btor_Op<"cmp", [
  NoSideEffect, SameTypeOperands,
  TypesMatchWith<
      "result type has !bv<1> element type and same shape as operands", "lhs",
      "result", "getI1SameShape($_self)">
] #ElementwiseMappable.traits> {
  let summary = "integer comparison operation";
  // clang-format off
  let description = [{
    The `cmp` operation is a generic comparison for two arguments 
    that need to have their types matching.

    Its first argument is an attribute that defines which type of comparison is
    performed. The following comparisons are supported:

    -   equal (mnemonic: `"eq"`; integer value: `0`)
    -   not equal (mnemonic: `"ne"`; integer value: `1`)
    -   signed less than (mnemonic: `"slt"`; integer value: `2`)
    -   signed less than or equal (mnemonic: `"sle"`; integer value: `3`)
    -   signed greater than (mnemonic: `"sgt"`; integer value: `4`)
    -   signed greater than or equal (mnemonic: `"sge"`; integer value: `5`)
    -   unsigned less than (mnemonic: `"ult"`; integer value: `6`)
    -   unsigned less than or equal (mnemonic: `"ule"`; integer value: `7`)
    -   unsigned greater than (mnemonic: `"ugt"`; integer value: `8`)
    -   unsigned greater than or equal (mnemonic: `"uge"`; integer value: `9`)

    The result is `1` if the comparison is true and `0` otherwise.

    Example:

    ```mlir
    // Custom form of scalar "signed less than" comparison.
    %x = btor.cmp "slt", %lhs, %rhs : !bv<1>
    ```
  }];

  let arguments = (ins BtorPredicateAttr: $predicate,
                   Btor_BitVec: $lhs,
                   Btor_BitVec: $rhs);
  let results = (outs Btor_BitVec : $result);

  let builders =
      [OpBuilder<(ins "BtorPredicate": $predicate, 
                  "Value": $lhs,
                  "Value": $rhs),
      [{
        build($_builder, $_state, ::getI1SameShape(lhs.getType()),
              predicate, lhs, rhs);
      }]>];
  let extraClassDeclaration = [{
    static StringRef getPredicateAttrName() { return "predicate"; }
    static BtorPredicate getPredicateByName(StringRef name);

    BtorPredicate getPredicate() {
      return (BtorPredicate)(*this)->getAttrOfType<IntegerAttr>(
            getPredicateAttrName()).getInt();
    }
  }];
  let verifier = [{ return verifyCmpOp(*this); }];
  let assemblyFormat =
      "$predicate `,` $lhs `,` $rhs attr-dict `:` qualified(type($lhs))";
  // clang-format on
}

def IffOp : BtorBinaryOp<"iff"> {
  let summary = "integer if-and-only-if operation";
  // clang-format off
  let description = [{
    This operation takes two !bv<1> arguments and returns a !bv<1>.

    Example:
        
    ```mlir
    %res = btor.iff %lhs, %rhs: !bv<1>
    ```
  }];
  let verifier = [{ return verifyBooleanOp(*this); }];
  // clang-format on
}

def ImpliesOp : BtorBinaryOp<"implies"> {
  let summary = "integer implication operation";
  // clang-format off
  let description = [{
    This operation takes two !bv<1> arguments and returns a !bv<1>.

    Example:
        
    ```mlir
    %res = btor.implies %lhs, %rhs: !bv<1>
    ```
  }];
  let verifier = [{ return verifyBooleanOp(*this); }];
  // clang-format on
}

def ShiftLLOp : BtorBinaryOp<"sll"> {
  let summary = "integer left logical shift binary operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.sll %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def ShiftRLOp : BtorBinaryOp<"srl"> {
  let summary = "integer right logical shift operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
      ```mlir
      %res = btor.srl %lhs, %rhs: !bv<32>
      ```
  }];
  // clang-format on
}

def ShiftRAOp : BtorBinaryOp<"sra"> {
  let summary = "integer right arithmetic shift operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.sra %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def RotateLOp : BtorBinaryOp<"rol"> {
  let summary = "integer left rotate operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.rol %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def RotateROp : BtorBinaryOp<"ror"> {
  let summary = "integer right rotate operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments and returns an integer.

    Example:
        
    ```mlir
    %res = btor.ror %lhs, %rhs: !bv<32>
    ```
  }];
  // clang-format on
}

def ConcatOp : Btor_Op<"concat"> {
  let summary = "integer concatenation operation";
  // clang-format off
  let description = [{
    This operation takes two integer arguments of length N and M
    and returns an integer of length N + M

    Example:
        
    ```mlir
    %res = btor.concat %lhs, %rhs: !bv<3>, !bv<2>, !bv<5>
    ```
  }];

  let arguments = (ins Btor_BitVec : $lhs, Btor_BitVec : $rhs);
  let results = (outs Btor_BitVec : $result);
  let parser = [{ return parseConcatOp(parser, result); }];
  let printer = [{ return printConcatOp(p, *this); }];
  let verifier = [{ return verifyConcatOp<btor::BitVecType>(*this); }];
  // clang-format on
}

//===----------------------------------------------------------------------===//
// btor unary integer ops definitions
//===----------------------------------------------------------------------===//

// Base class for unary ops. Requires single operand and result. Individual
// classes will have `operand` accessor.
// clang-format off
class BtorUnaryOp<string mnemonic, list<Trait> traits = []>
    : Op<Btor_Dialect, mnemonic,
         !listconcat(traits, [NoSideEffect, SameOperandsAndResultType])>,
      Arguments<(ins Btor_BitVec: $operand)>,
      Results<(outs Btor_BitVec: $result)> {

  let assemblyFormat = "$operand attr-dict `:` qualified(type($result))";
  // clang-format on
}

// This operation takes an operand
// and returns one result of type bv<1>
//
//     <op> %0 : !bv<1>
// clang-format off
class BtorUnaryDifferentResultTypeOp<string mnemonic, list<Trait> traits = []>
    : Op<Btor_Dialect, mnemonic, !listconcat(traits, [NoSideEffect])>,
      Arguments<(ins Btor_BitVec: $operand)> {

  let results = (outs Btor_BitVec : $result);
  let parser = [{ return parseUnaryDifferentResultOp(parser, result); }];
  let printer = [{ return printBtorUnaryOp(p, this->getOperation()); }];
  // clang-format on
}

def NotOp : BtorUnaryOp<"not"> {
  let summary = "integer negation";
  // clang-format off
  let description = [{
    The `not` operation computes the negation of a given value.
    It takes one operand and returns one result of the same type.

    Example:

    ```mlir
    // Scalar negation value.
    %a = btor.not %b: !bv<32>
    ```
  }];
  // clang-format on
}

def IncOp : BtorUnaryOp<"inc"> {
  let summary = "integer increment by one";
  // clang-format off
  let description = [{
    The `inc` operation increments the given value by one.
    It takes one operand and returns one result of the same type.

    Example:

    ```mlir
    // Scalar increment value.
    %a = btor.inc %b: !bv<32>
    ```
  }];
  // clang-format on
}

def DecOp : BtorUnaryOp<"dec"> {
  let summary = "integer decrement by one";
  // clang-format off
  let description = [{
    The `dec` operation decrements the given value byone.
    It takes one operand and returns one result of the same type.

    Example:

    ```mlir
    // Scalar decrement value.
    %a = btor.dec %b: !bv<32>
    ```
  }];
  // clang-format on
}

def NegOp : BtorUnaryOp<"neg"> {
  let summary = "integer negation";
  // clang-format off
  let description = [{
    The `neg` operation flips the sign of a given value.
    It takes one operand and returns one result of the same type.

    Example:

    ```mlir
    // Scalar decrement value.
    %a = btor.neg %b: !bv<32>
    ```
  }];
  // clang-format on
}

def RedAndOp : BtorUnaryDifferentResultTypeOp<"redand"> {
  let summary = "integer reduction with and operator";
  // clang-format off
  let description = [{
    The `redand` operation computes the and reduction of a given value. It takes one
    operand and returns one result of type !bv<1>. 

    Example:

    ```mlir
    // Scalar redand value.
    %a = btor.redand %b : !bv<1>
    ```
  }];
  // clang-format on
}

def RedOrOp : BtorUnaryDifferentResultTypeOp<"redor"> {
  let summary = "integer reduction with or operator";
  // clang-format off
  let description = [{
    This operation computes the or reduction of a given value. It takes one
    operand and returns one result of type !bv<1>. 

    Example:

    ```mlir
    // Scalar redand value.
    %a = btor.redand %b : !bv<1>
    ```
  }];
  // clang-format on
}

def RedXorOp : BtorUnaryDifferentResultTypeOp<"redxor"> {
  let summary = "integer reduction with and operator";
  // clang-format off
  let description = [{
    This operation computes the xor reduction of a given value. It takes one
    operand and returns one result of type !bv<1>. 

    Example:

    ```mlir
    // Scalar redand value.
    %a = btor.redand %b : !bv<1>
    ```
  }];
  // clang-format on
}

def AssertNotOp : Btor_Op<"assert_not"> {
  let summary = "btor assertion to mimic bad operation";
  // clang-format off
  let description = [{
    This operation takes one boolean argument and terminates
    the program if the argument is false.

    Example :
    
    ```mlir
    // Apply the assert operation to %0
    btor.assert_not(%0)
    ```
  }];
  let arguments = (ins Btor_BitVec : $arg, AnyI64Attr : $id);
  let assemblyFormat = "`(` $arg `)` attr-dict `,` $id qualified(type($arg))";
  // clang-format on
}

def ConstantOp : Btor_Op<"constant", [ConstantLike, NoSideEffect]> {
  let summary = "integer constant";
  // clang-format off
  let description = [{
    The `constant` operation produces an SSA value equal to some constant
        specified by an attribute.

    Example:

    ```mlir
    // Integer constant
    %1 = constant 42: !bv<32>
    ```
  }];
  let arguments = (ins Builtin_IntegerAttr : $value);
  let results = (outs Btor_BitVec : $result);
  let assemblyFormat = "attr-dict $value qualified(type($result))";
  let verifier = [{ return verifyConstantOp(*this); }];
  let hasFolder = 1;
  // clang-format on
}

def ConstraintOp : Btor_Op<"constraint"> {
  let summary = "btor constraint";
  // clang-format off
  let description = [{
    This operation takes one boolean argument and assumes 
    it holds for the program.

    Example:
    
    ```mlir
    %0 = constant 1 : !bv<1>
    // Apply the constraint operation to %0
    btor.constraint ( %0 ) : !bv<1>
    ```
  }];
  let arguments = (ins Btor_BitVec : $constraint);
  let assemblyFormat =
      "`(` $constraint `)` attr-dict `:` qualified(type($constraint))";
  let verifier = [{ return verifyConstraintOp(*this); }];
  // clang-format on
}

def NDStateOp : Btor_Op<"nd_state"> {
  let summary = "btor nondet bv state";
  // clang-format off
  let description = [{
    This operation takes no input and returns a BitVecType

    Example:

      ```mlir
      // invoke the nd_bv operation
      % 0 = btor.nd_state 15: !bv<32>
      ``` 
    In the example above, 15 gets interpreted as an i64 integer to 
    represent the 15th input of a circuit
  }];
  let arguments = (ins AnyI64Attr : $id);
  let results = (outs Btor_BitVec : $result);
  let parser = [{ return parseNDStateOpOp(parser, result); }];
  let printer = [{ return printNDStateOpOp(p, *this); }];
  // clang-format on
}

def InputOp : Btor_Op<"input"> {
  let summary = "btor input";
  // clang-format off
  let description = [{
    This operation takes an input number and then returns a BitVec Type value

    Example:

      ```mlir
      // invoke the input operation to %0
      % 0 = btor.input 15: !bv<32>
      ```
    In the example above, 15 gets interpreted as an i64 integer to represent 
    the line number of the input
  }];
  let arguments = (ins AnyI64Attr : $id);
  let results = (outs Btor_BitVec : $result);
  let parser = [{ return parseInputOp(parser, result); }];
  let printer = [{ return printInputOp(p, *this); }];
  // clang-format on
}

//===----------------------------------------------------------------------===//
// Vector using Btor arrays
//===----------------------------------------------------------------------===//

def VectorInitArrayOp : Btor_Op<"array_vec"> {
  let summary = "btor initialized array allocation using vector types";
  // clang-format off
  let description = [{
    The `array` operation represents a btor array, using vectors,
    that has been initialized with a value.

    For example:

    ```mlir
    %4 = btor.array_vec %1: vector<8xi32>
    ```
    This operation returns a single SSA value of a vector type
    used by subsequent read and write operations.
  }];
  let arguments = (ins SignlessIntegerLike : $init);
  let results = (outs AnyVector : $result);
  let extraClassDeclaration = [{
    VectorType getArrayType() {
      return result().getType().cast<VectorType>();
    }
  }];
  let verifier = [{ return verifyVectorInitArrayOp(*this); }];
  let parser = [{ return parseVectorInitArrayOp(parser, result); }];
  let printer = [{ return printVectorInitArrayOp(p, *this); }];
// clang-format on
}

def VectorReadOp : Btor_Op<"read_vec"> {
  let summary = "btor read operation using vector types";
  // clang-format off
  let description = [{
    The `read` op reads an element from a btor array specified by an index.
    The output of load is a new value with the same type as the elements
    of the btor array.

    Example:

    ```mlir 
    %1 = btor.read %A[%0]: vector<8xi32>, i32
    ```
  }];

  let arguments = (ins AnyVector : $base,
                      SignlessIntegerLike : $index);
  let results = (outs SignlessIntegerLike : $result);
  let extraClassDeclaration = [{
    VectorType getArrayType() {
      return base().getType().cast<VectorType>();
    }
  }];
  let verifier = [{ return verifyVectorReadOp(*this); }];
  let parser = [{ return parseVectorReadOp(parser, result); }];
  let printer = [{ return printVectorReadOp(p, *this); }];
// clang-format on
}

def VectorWriteOp : Btor_Op<"write_vec"> {
  let summary = "btor write operation with vector types";
  // clang-format off
  let description = [{
    Copy the given array and write the given value to the provided location
    given by index.The value stored should have the same type as the 
    elemental type of the array.Example:

    ```mlir
    %4 = btor.write %2, %A[%1]: vector<8xi32>
    ```
  }];

  let arguments = (ins SignlessIntegerLike: $value,
                    AnyVector: $base, 
                    SignlessIntegerLike: $index);

  let results = (outs AnyVector : $result);
  let extraClassDeclaration = [{
    VectorType getArrayType() {
      return base().getType().cast<VectorType>();
    }
  }];
  let verifier = [{ return verifyVectorWriteOp(*this); }];
  let parser = [{ return parseVectorWriteOp(parser, result); }];
  let printer = [{ return printVectorWriteOp(p, *this); }];
// clang-format on
}

//===----------------------------------------------------------------------===//
// MemRef using Btor arrays
//===----------------------------------------------------------------------===//

def MemRefInitArrayOp : Btor_Op<"array_mem"> {
  let summary = "btor initialized array allocation using memref types";
  // clang-format off
  let description = [{
    The `array` operation represents a btor array, using memrefs,
    that has been initialized with a value.

    For example:

    ```mlir
    %4 = btor.array_mem %1: memref<8xi32>
    ```
    This operation returns a single SSA value of a memref type
    used by subsequent read and write operations.
  }];
  let arguments = (ins Builtin_IntegerAttr : $init);
  let results = (outs AnyMemRef : $result);
  let extraClassDeclaration = [{
    MemRefType getArrayType() {
      return result().getType().cast<MemRefType>();
    }
  }];
  let verifier = [{ return verifyMemRefInitArrayOp(*this); }];
  let parser = [{ return parseMemRefInitArrayOp(parser, result); }];
  let printer = [{ return printMemRefInitArrayOp(p, *this); }];
// clang-format on
}

def MemRefReadOp : Btor_Op<"read_mem"> {
  let summary = "btor read operation using memref types";
  // clang-format off
  let description = [{
    The `read` op reads an element from a btor array specified by an index.
    The output of load is a new value with the same type as the elements
    of the btor array.

    Example:

    ```mlir 
    %1 = btor.read %A[%0]: memref<8xi32>, i32
    ```
  }];

  let arguments = (ins AnyMemRef : $base,
                      SignlessIntegerLike : $index);
  let results = (outs SignlessIntegerLike : $result);
  let extraClassDeclaration = [{
    MemRefType getArrayType() {
      return base().getType().cast<MemRefType>();
    }
  }];
  let verifier = [{ return verifyMemRefReadOp(*this); }];
  let parser = [{ return parseMemRefReadOp(parser, result); }];
  let printer = [{ return printMemRefReadOp(p, *this); }];
// clang-format on
}

def MemRefWriteOp : Btor_Op<"write_mem"> {
  let summary = "btor write operation with memref types";
  // clang-format off
  let description = [{
    Copy the given array and write the given value to the provided location
    given by index.The value stored should have the same type as the 
    elemental type of the array.Example:

    ```mlir
    %4 = btor.write %2, %A[%1]: memref<8xi32>
    ```
  }];

  let arguments = (ins SignlessIntegerLike: $value,
                    AnyMemRef: $base, 
                    SignlessIntegerLike: $index);

  let results = (outs AnyMemRef : $result);
  let extraClassDeclaration = [{
    MemRefType getArrayType() {
      return base().getType().cast<MemRefType>();
    }
  }];
  let verifier = [{ return verifyMemRefWriteOp(*this); }];
  let parser = [{ return parseMemRefWriteOp(parser, result); }];
  let printer = [{ return printMemRefWriteOp(p, *this); }];
// clang-format on
}

//===----------------------------------------------------------------------===//
// Btor arrays
//===----------------------------------------------------------------------===//

def ArrayOp : Btor_Op<"nd_array"> {
  let summary = "btor array allocation operation";
  // clang-format off
  let description = [{
    The `nd_array` operation represents a btor array from 
    bitvec -> bitvec. For example:

    ```mlir
    %0 = btor.nd_array : !array<!bv<8>,!bv<32>>
    ```

    This operation returns a single SSA value of a btor array type used
    by subsequent read and write operations. 
  }];

  let arguments = (ins AnyI64Attr : $id);
  let results = (outs Btor_Array : $result);
  let extraClassDeclaration = [{
    ArrayType getArrayType() {
      return result().getType().cast<ArrayType>();
    }
  }];
  let parser = [{ return parseArrayOp(parser, result); }];
  let printer = [{ return printArrayOp(p, *this); }];
// clang-format on
}

def InitArrayOp : Btor_Op<"array"> {
  let summary = "btor initialized array allocation operation";
  // clang-format off
  let description = [{
    The `array` operation represents a btor array from
        bitvec->bitvec that has been initialized with a value.

    For example:

    ```mlir
    % 4 = btor.array %1: !array<!bv<8>, !bv<32>>
    ```
    This operation returns a single SSA value of a btor array type used
    by subsequent read and write operations.
  }];

  let extraClassDeclaration = [{
    ArrayType getArrayType() {
      return result().getType().cast<ArrayType>();
    }
  }];
  let arguments = (ins Btor_BitVec : $init);
  let results = (outs Btor_Array : $result);
  let verifier = [{ return verifyInitArrayOp(*this); }];
  let parser = [{ return parseInitArrayOp(parser, result); }];
  let printer = [{ return printInitArrayOp(p, *this); }];
// clang-format on
}

def ReadOp : Btor_Op<"read"> {
  let summary = "btor read operation";
  // clang-format off
  let description = [{
    The `read` op reads an element from a btor array specified by an index.
    The output of load is a new value with the same type as the elements
    of the btor array.

    Example:

    ```mlir
    % 1 = btor.read %A[%0]: !array<!bv<8>, !bv<32>>, !bv<32>
    ```
  }];

  let extraClassDeclaration = [{
    ArrayType getArrayType() {
      return base().getType().cast<ArrayType>();
    }
  }];
  let arguments = (ins Btor_Array : $base, Btor_BitVec : $index);
  let results = (outs Btor_BitVec : $result);
  let verifier = [{ return verifyReadOp(*this); }];
  let parser = [{ return parseReadOp(parser, result); }];
  let printer = [{ return printReadOp(p, *this); }];
// clang-format on
}

def WriteOp : Btor_Op<"write"> {
  let summary = "btor write operation";
  // clang-format off
  let description = [{
    Copy the given array and write the given value to the provided location
    given by index. The value stored should have the same type as the 
    elemental type of the array.Example:

    ```mlir
    % 4 = btor.write %2, %A[%1]: !array<!bv<8>, !bv<32>>
    ```
  }];

  let arguments = (ins Btor_BitVec: $value,
                      Btor_Array: $base,
                      Btor_BitVec: $index);

  let results = (outs Btor_Array : $result);
  let extraClassDeclaration = [{
    ArrayType getArrayType() {
      return base().getType().cast<ArrayType>();
    }
  }];
  let verifier = [{ return verifyWriteOp(*this); }];
  let parser = [{ return parseWriteOp(parser, result); }];
  let printer = [{ return printWriteOp(p, *this); }];
// clang-format on
}

def WriteInPlaceOp : Btor_Op<"write_in_place"> {
  let summary = "btor write in place operation";
  // clang-format off
  let description = [{
    Write the given value to the provided location given by index.
    The value stored should have the same type as the elemental type
    of the array. Example:

    ```mlir
    % 4 = btor.write_in_place %2, %A[%1]: !array<!bv<8>, !bv<32>>
    ```
  }];

  let arguments = (ins Btor_BitVec: $value,
                      Btor_Array: $base,
                      Btor_BitVec: $index);

  let results = (outs Btor_Array : $result);
  let extraClassDeclaration = [{
    ArrayType getArrayType() {
      return base().getType().cast<ArrayType>();
    }
  }];
  let verifier = [{ return verifyWriteOp(*this); }];
  let parser = [{ return parseWriteOp(parser, result); }];
  let printer = [{ return printWriteOp(p, *this); }];
// clang-format on
}

def IteWriteInPlaceOp : Btor_Op<"ite_write_in_place"> {
  let summary = "btor conditional write in place operation";
  // clang-format off
  let description = [{
    Write the given value to the provided location given by index if
    the condition is true. The value stored should have the same type as
    the elemental type of the array. Example:

    ```mlir
    % 4 = btor.ite_write_in_place %3, %2, %A[%1]: !array<!bv<8>, !bv<32>>
    ```
  }];

  let arguments = (ins Btor_BitVec: $condition,
                      Btor_BitVec: $value,
                      Btor_Array: $base,
                      Btor_BitVec: $index);

  let results = (outs Btor_Array : $result);
  let extraClassDeclaration = [{
    ArrayType getArrayType() {
      return base().getType().cast<ArrayType>();
    }
  }];
  let verifier = [{ return verifyIteWriteInPlaceOp(*this); }];
  let parser = [{ return parseIteWriteInPlaceOp(parser, result); }];
  let printer = [{ return printIteWriteInPlaceOp(p, *this); }];
// clang-format on
}

#endif // BTOR_OPS
