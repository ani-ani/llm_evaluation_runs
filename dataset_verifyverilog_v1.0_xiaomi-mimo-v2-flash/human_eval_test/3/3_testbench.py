import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    if v < 0:
        # For signed clamping, keep within signed range
        min_val = -(1 << (bits - 1))
        max_val = (1 << (bits - 1)) - 1
        return max(min_val, min(v, max_val))
    else:
        max_val = (1 << bits) - 1
        return min(v, max_val)

def to_signed(val, bits):
    # Convert Python int to signed representation for HDL if needed
    # Here we just clamp, as the value is passed directly
    return clamp_to_width(val, bits)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'ops_valid'):
        dut.ops_valid.value = 0
    dut.op.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done signal not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_below_zero(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Cases based on provided Python function examples
    # Format: (list of operations, expected_below_zero)
    test_cases = [
        ([], False),
        ([1, 2, 3], False),
        ([1, 2, -4, 5], True),
        ([1, 2, -3, 1, 2, -3], False),
        ([1, 2, -4, 5, 6], True),
        ([1, -1, 2, -2, 5, -5, 4, -4], False),
        ([1, -1, 2, -2, 5, -5, 4, -5], True),
        ([1, -2, 2, -2, 5, -5, 4, -4], True)
    ]
    
    passed = 0
    failed = 0
    
    for i, (ops, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test Case {i+1}: Operations={ops}, Expected={expected}")
        
        # Start sequence
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream operations
        for op_val in ops:
            dut.ops_valid.value = 1
            dut.op.value = to_signed(op_val, 8)
            await RisingEdge(dut.clk)
        
        # End sequence
        dut.ops_valid.value = 0
        dut.op.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=100)
            
            # Check result
            if not is_value_defined(dut.below_zero.value):
                raise TestFailure("below_zero signal is undefined")
            
            result = int(dut.below_zero.value)
            if bool(result) != expected:
                raise TestFailure(f"Expected below_zero={expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        
        # Reset for next test case
        await reset_dut(dut)
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
