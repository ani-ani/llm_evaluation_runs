import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Testbench constants
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_dict_empty_check(dut):
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    # Test case 1: Empty dictionary (initial state)
    dut.start.value = 1
    dut.op.value = 0  # check_empty
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done with timeout
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Test 1 failed: Expected empty (1), got {result}")
    
    # Test case 2: Insert one element and check
    dut.op.value = 1  # insert
    dut.key.value = 10  # index 10
    dut.value.value = 55  # arbitrary value
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(200, units='ns')  # Wait for insert
    
    # Check non-empty
    dut.op.value = 0  # check_empty
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Test 2 failed: Expected not empty (0), got {result}")
    
    # Test case 3: Remove element and check
    dut.op.value = 2  # remove
    dut.key.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(200, units='ns')
    
    # Check empty again
    dut.op.value = 0  # check_empty
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Test 3 failed: Expected empty (1), got {result}")
    
    # Test case 4: Clear and check (simulating dict clear)
    dut.op.value = 3  # clear
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(200, units='ns')
    
    dut.op.value = 0  # check_empty
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Test 4 failed: Expected empty (1), got {result}")
    
    cocotb.log.info("All tests passed!")