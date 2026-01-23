import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_dna_editing(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for i in range(2000):
        dut.op1_type[i].value = 0
        dut.op1_pos[i].value = 0
        dut.op1_char[i].value = 0
        dut.op2_type[i].value = 0
        dut.op2_pos[i].value = 0
        dut.op2_char[i].value = 0
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Del(1) Del(2) vs Del(3) Del(1) -> 0
    dut.op1_type[0].value = 0
    dut.op1_pos[0].value = 1
    dut.op1_type[1].value = 0
    dut.op1_pos[1].value = 2
    
    dut.op2_type[0].value = 0
    dut.op2_pos[0].value = 3
    dut.op2_type[1].value = 0
    dut.op2_pos[1].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(100, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    if int(dut.result.value) != 0:
        raise TestFailure(f"Test 1: expected 0, got {int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: Del(2) Del(1) vs Del(1) Del(2) -> 1
    dut.op1_type[0].value = 0
    dut.op1_pos[0].value = 2
    dut.op1_type[1].value = 0
    dut.op1_pos[1].value = 1
    
    dut.op2_type[0].value = 0
    dut.op2_pos[0].value = 1
    dut.op2_type[1].value = 0
    dut.op2_pos[1].value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(100, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    if int(dut.result.value) != 1:
        raise TestFailure(f"Test 2: expected 1, got {int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: Ins(1,X) Del(1) vs empty -> 0
    dut.op1_type[0].value = 1
    dut.op1_pos[0].value = 1
    dut.op1_char[0].value = ord('X')
    dut.op1_type[1].value = 0
    dut.op1_pos[1].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(100, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    if int(dut.result.value) != 0:
        raise TestFailure(f"Test 3: expected 0, got {int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: Ins(14,B) Ins(14,A) vs Ins(14,A) Ins(15,B) -> 0
    dut.op1_type[0].value = 1
    dut.op1_pos[0].value = 14
    dut.op1_char[0].value = ord('B')
    dut.op1_type[1].value = 1
    dut.op1_pos[1].value = 14
    dut.op1_char[1].value = ord('A')
    
    dut.op2_type[0].value = 1
    dut.op2_pos[0].value = 14
    dut.op2_char[0].value = ord('A')
    dut.op2_type[1].value = 1
    dut.op2_pos[1].value = 15
    dut.op2_char[1].value = ord('B')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(100, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    if int(dut.result.value) != 0:
        raise TestFailure(f"Test 4: expected 0, got {int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 5: Ins(14,A) Ins(15,B) vs Ins(14,B) Ins(15,A) -> 1
    dut.op1_type[0].value = 1
    dut.op1_pos[0].value = 14
    dut.op1_char[0].value = ord('A')
    dut.op1_type[1].value = 1
    dut.op1_pos[1].value = 15
    dut.op1_char[1].value = ord('B')
    
    dut.op2_type[0].value = 1
    dut.op2_pos[0].value = 14
    dut.op2_char[0].value = ord('B')
    dut.op2_type[1].value = 1
    dut.op2_pos[1].value = 15
    dut.op2_char[1].value = ord('A')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(100, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    if int(dut.result.value) != 1:
        raise TestFailure(f"Test 5: expected 1, got {int(dut.result.value)}")