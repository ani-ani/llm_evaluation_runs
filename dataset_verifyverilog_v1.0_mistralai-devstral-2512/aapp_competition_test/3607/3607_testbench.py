import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import struct

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    # Handle signed logic if needed, but here assuming unsigned packed bits
    return v & max_val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def create_instruction(opcode, operand, data, target=0):
    # opcode: 0-3, operand: 8 bits, data: 32 bits (int/str), target: 16 bits
    # Returns 64-bit int
    inst = 0
    inst |= (opcode & 0xFF)
    inst |= ((operand & 0xFF) << 8)
    inst |= ((data & 0xFFFFFFFF) << 16)
    inst |= ((target & 0xFFFF) << 48)
    return inst

def create_string_data(s):
    # Pack 8 chars into 64 bits (big endian, left aligned)
    s_padded = s.ljust(8, ' ')[:8]
    val = 0
    for i, c in enumerate(s_padded):
        val |= (ord(c) << (56 - i*8))
    return val

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_basic_interpreter(dut):
    # Setup clock if sequential
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # --- Test Case 1: Simple Loop ---
    # Program:
    # 10 LET A = 1
    # 20 PRINT "HELLO "
    # 30 PRINTLN A
    # 40 LET A = A + 1
    # 50 IF A <= 5 THEN GOTO 20
    # 60 PRINTLN "DONE"
    
    instructions = []
    
    # 10 LET A = 1 (A=65)
    # Opcode LET=0, Operand A=65, Data=1, Target=0
    instructions.append(create_instruction(0, 65, 1, 0))
    
    # 20 PRINT "HELLO "
    # Opcode PRINT=2, Operand 0, Data=String
    s1 = create_string_data("HELLO ")
    instructions.append(create_instruction(2, 0, s1, 0))
    
    # 30 PRINTLN A
    # Opcode PRINTLN=3, Operand A=65
    instructions.append(create_instruction(3, 65, 0, 0))
    
    # 40 LET A = A + 1
    # Opcode LET=0, Operand A=65, Data=1 (Implies A + 1? Need specific format)
    # Let's use a specific format: Data contains literal or encoded operation.
    # For simplicity in benchmark: LET A = A + 1 -> Operand A, Data 1 (add), Op code specific for ADD
    # Re-designing instruction for simplicity:
    # Bits [7:0]: Opcode (0=LET, 1=IF, 2=PRINT, 3=PRINTLN)
    # Bits [15:8]: Dest Var
    # Bits [23:16]: Src Var (or 0 for literal)
    # Bits [55:24]: Literal Value (or String ID)
    # Bits [63:56]: Target Label (Index)
    
    # Revised Instructions for Testbench alignment:
    # LET A = 1 -> Op=0, Dest=A(65), Src=0(Literal), Val=1
    instructions[0] = (0) | (65 << 8) | (0 << 16) | (1 << 24) | (0 << 56)
    
    # PRINT "HELLO " -> Op=2, String ID 0 (embedded in Val)
    instructions[1] = (2) | (0 << 8) | (0 << 16) | (s1 << 24) | (0 << 56)
    
    # PRINTLN A -> Op=3, Dest=A(65)
    instructions[2] = (3) | (65 << 8) | (0 << 16) | (0 << 24) | (0 << 56)
    
    # LET A = A + 1 -> Op=4 (ADD), Dest=A, Src=A, Val=1
    instructions[3] = (4) | (65 << 8) | (65 << 16) | (1 << 24) | (0 << 56)
    
    # IF A <= 5 THEN GOTO 20 (Label 1) -> Op=1 (IF), Dest=A(65), Val=5, Target=1
    # Cond code in Src? Let's put Cond in upper bits of Src.
    # Let's use: Op=1, Dest=A, Src=Cond|ValSrc, Val=Literal, Target=LabelIdx
    instructions[4] = (1) | (65 << 8) | (0x04 << 16) | (5 << 24) | (1 << 56)
    
    # PRINTLN "DONE" -> Op=3, String ID 1
    s2 = create_string_data("DONE")
    instructions[5] = (3) | (0 << 8) | (0 << 16) | (s2 << 24) | (0 << 56)
    
    # Stop (NOP) - Label 2 (Not reached)
    instructions.append(0)
    
    # Load instructions into DUT memory
    # Verilog array access: dut.instruction_mem[i].value = val
    for i, inst in enumerate(instructions):
        if has_signal(dut, f'instruction_mem_{i}'):
            getattr(dut, f'instruction_mem_{i}').value = inst
        elif has_signal(dut, 'instruction_mem') and i < 16:
             dut.instruction_mem[i].value = inst
        else:
             # Fallback for flat bus or external mem simulation
             dut._log.warning(f"Cannot load instruction {i}")

    # Start
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Capture Output
    output_str = ""
    cycles = 0
    max_cycles = 1000
    
    while cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if has_signal(dut, 'output_valid') and int(dut.output_valid.value) == 1:
            char = int(dut.output_char.value)
            if char == 10: # Newline
                output_str += "\n"
            elif 32 <= char <= 126:
                output_str += chr(char)
        
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            break
    
    # Expected Output
    expected = "HELLO 1\nHELLO 2\nHELLO 3\nHELLO 4\nHELLO 5\nDONE\n"
    
    if output_str != expected:
        raise TestFailure(f"Output mismatch:\nGot: {repr(output_str)}\nExp: {repr(expected)}")
