# Verification Plan: 4-bit ALU

## 1. DUT Overview

**Module:** alu_4bit
**Function:** 4-bit Arithmetic Logic Unit (ALU) performing combinational arithmetic and logic operations on two 4-bit operands A and B, selected by a 3-bit opcode op.

| Opcode (op) | Operation | Description            | Example (A=3, B=2) | Y    | carry |
|-------------|-----------|------------------------|--------------------|------|-------|
| 000         | ADD       | Y = A + B              | 3 + 2              | 0101 | 0     |
| 001         | SUB       | Y = A - B (two's comp) | 3 - 2              | 0001 | 0     |
| 010         | AND       | Bitwise AND            | 3 & 2              | 0010 | 0     |
| 011         | OR        | Bitwise OR             | 3 \| 2             | 0011 | 0     |
| 100         | XOR       | Bitwise XOR            | 3 ^ 2              | 0001 | 0     |
| 101         | NOT A     | Bitwise negation of A  | ~3                 | 1100 | 0     |
| 110         | PASS A    | Output A               | 3                  | 0011 | 0     |
| 111         | PASS B    | Output B               | 2                  | 0010 | 0     |

## 2. Verification Objectives

- Verify correct Y output for each of the 8 operations across all input combinations
- Verify correct carry/borrow bit for ADD and SUB (including overflow and borrow cases)
- Verify carry is explicitly 0 for all logical operations (AND, OR, XOR, NOT, PASS A, PASS B)
- Verify correct opcode decoding (no operation bleed between opcodes)
- Verify invalid/unknown opcode drives Y=0000 and carry=0

## 3. Test Strategy

**Strategy:** Exhaustive combinatorial testing using a reference model.

For each of the 9 test cases, all relevant input combinations of A and B are applied. The DUT output (Y, carry) is compared against a behavioral reference model. Any mismatch is logged with full input context and categorized by type.

**Total vectors:** 2,048 (8 ops × 16 A values × 16 B values) + 1 invalid opcode vector = **2,049 test vectors**

## 4. Test Cases

| Test ID | Operation  | opcode | Inputs Tested              | Checks                          |
|---------|------------|--------|----------------------------|---------------------------------|
| T1      | ADD        | 000    | All A[3:0], B[3:0] (256)   | Y = lower 4 bits, carry = MSB   |
| T2      | SUB        | 001    | All A[3:0], B[3:0] (256)   | Y = A-B mod 16, carry on borrow |
| T3      | AND        | 010    | All A[3:0], B[3:0] (256)   | Y = A & B, carry = 0            |
| T4      | OR         | 011    | All A[3:0], B[3:0] (256)   | Y = A \| B, carry = 0           |
| T5      | XOR        | 100    | All A[3:0], B[3:0] (256)   | Y = A ^ B, carry = 0            |
| T6      | NOT A      | 101    | All A[3:0], B[3:0] (256)   | Y = ~A, carry = 0               |
| T7      | PASS A     | 110    | All A[3:0], B[3:0] (256)   | Y = A, carry = 0                |
| T8      | PASS B     | 111    | All A[3:0], B[3:0] (256)   | Y = B, carry = 0                |
| T9      | Invalid op | X      | A=1010, B=0101 (1 vector)  | Y = 0000, carry = 0             |

**Total: 9 tests**

## 5. Testbench Architecture

- **Reference model:** Behavioral SystemVerilog module (`alu_compare_4bit`) implementing all 8 operations, used as golden reference
- **Comparison:** Bit-exact comparison using `!==` (detects X/Z mismatches)
- **Error categorization:** Mismatches are classified as Y-only, carry-only, or both — tracked per operation
- **Waveform dump:** VCD file generated for waveform inspection (ADD operations visible in wave viewer)

## 6. Coverage Goals

- **Input space:** 100% — all 2,048 valid input combinations exercised
- **Opcode coverage:** All 8 defined opcodes + invalid opcode case
- **Carry conditions:** ADD carry=1 triggered when A+B > 15; SUB carry=1 triggered when A < B

## 7. Pass/Fail Criteria

- **PASS:** All 2,049 vectors produce outputs matching the reference model
- **FAIL:** Any mismatch in Y or carry for any input combination; report identifies the failing operation and input values
