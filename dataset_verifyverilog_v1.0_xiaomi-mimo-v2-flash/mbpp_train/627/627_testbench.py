import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

async def write_array(dut, vals, width=8):
    for i in range(8):
        if i < len(vals):
            v = clamp_to_width(vals[i], width)
        else:
            v = 0
        dut.arr[i].value = v

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_missing(dut):
    CLK_NS = 10
    DATA_WIDTH = 8
    ARRAY_SIZE = 8
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([0,1,2,3], 4),
        ([0,1,2,6,9], 3),
        ([2,3,5,8,9], 0),
        ([0,1,2,3,4,5,6,7], 8),
        ([1,2,3,4,5,6,7,8], 0),
    ]
    
    for test_idx, (input_arr, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: Input={input_arr}, Expected={expected}")
        
        # Write input array
        await write_array(dut, input_arr, DATA_WIDTH)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, 200)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
        result = int(dut.result.value)
        
        # Clamp expected to 8-bit (max 255)
        expected_clamped = clamp_to_width(expected, DATA_WIDTH)
        
        if result != expected_clamped:
            raise TestFailure(f"Test {test_idx+1}: Expected {expected_clamped}, got {result}")
        else:
            cocotb.log.info(f"Test {test_idx+1} PASSED")
        
        # Reset between tests
        await reset_dut(dut)
        
    cocotb.log.info("All tests passed!")