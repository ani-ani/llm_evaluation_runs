import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, vals, width, array_size=8):
    # Clear all array elements first
    for i in range(array_size):
        dut.arr[i].value = 0
    # Write only valid values
    for i, v in enumerate(vals):
        if i < array_size:
            dut.arr[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_is_product_even(dut):
    # Configuration
    DATA_WIDTH = 8
    ARRAY_SIZE = 8
    CLK_NS = 10
    MAX_CYCLES = 100
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([1, 2, 3], 1, "One even number"),
        ([1, 1], 0, "All odd numbers"),
        ([1, 2, 1, 4], 1, "Multiple even numbers"),
        ([0, 1, 1], 1, "Zero is even"),
        ([1, 3, 5, 7, 9, 11, 13, 15], 0, "All odd, full array"),
        ([2, 4, 6, 8, 10, 12, 14, 16], 1, "All even, full array"),
        ([1], 0, "Single odd"),
        ([2], 1, "Single even")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input array
            await write_array(dut, inp, DATA_WIDTH, ARRAY_SIZE)
            # Write length
            dut.len.value = len(inp)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        
        # Small delay between tests
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
