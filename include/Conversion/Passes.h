#ifndef BTOR_CONVERSION_PASSES_H
#define BTOR_CONVERSION_PASSES_H

#include "Conversion/BtorNDToLLVM/ConvertBtorNDToLLVMPass.h"
#include "Conversion/BtorToArithmetic/ConvertBtorToArithmeticPass.h"
#include "Conversion/BtorToLLVM/ConvertBtorToLLVMPass.h"
#include "Conversion/BtorToMemref/ConvertBtorToMemrefPass.h"
#include "Conversion/BtorToVector/ConvertBtorToVectorPass.h"

namespace mlir {
namespace btor {

/// Generate the code for registering conversion passes.
#define GEN_PASS_REGISTRATION
#include "Conversion/Passes.h.inc"

} // namespace btor
} // namespace mlir

#endif // BTOR_CONVERSION_PASSES_H
