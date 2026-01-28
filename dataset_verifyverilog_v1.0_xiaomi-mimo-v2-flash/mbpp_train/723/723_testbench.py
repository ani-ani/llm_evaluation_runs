import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers (as per instructions) ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# --- Testbench Constants ---
DATA_WIDTH = 8
MAX_LEN = 8
CLK_NS = 10
MAX_CYCLES = 100

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def run_test_case(dut, arr1_vals, arr2_vals):
    length = len(arr1_vals)
    
    # Pad or truncate to MAX_LEN if needed for hardware inputs
    # Hardware expects inputs for all 8 slots, but uses 'len' to control logic
    arr1_hw = [0] * MAX_LEN
    arr2_hw = [0] * MAX_LEN
    for i in range(length):
        arr1_hw[i] = to_signed(arr1_vals[i], DATA_WIDTH)
        arr2_hw[i] = to_signed(arr2_vals[i], DATA_WIDTH)
    
    # Set inputs
    dut.len.value = length
    
    # Handle array inputs: Individual element assignment
    for i in range(MAX_LEN):
        # Using bit slice or index depending on Verilog module definition.
        # Assuming 'arr1_i' is a vector or array of ports.
        # If it's a packed vector: 
        # dut.arr1_i.value = pack_array(arr1_hw, DATA_WIDTH)
        # If it's unpacked ports:
        getattr(dut, f'arr1_i[{i}]').value = clamp_to_width(arr1_hw[i], DATA_WIDTH)
        getattr(dut, f'arr2_i[{i}]').value = clamp_to_width(arr2_hw[i], DATA_WIDTH)
    
    # Trigger
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    await wait_for_done(dut)
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result signal undefined")
    
    result = int(dut.result.value)
    
    # Calculate expected
    expected = 0
    for i in range(length):
        if arr1_vals[i] == arr2_vals[i]:
            expected += 1
            
    if result != expected:
        raise TestFailure(f"Mismatch: Expected {expected}, got {result}")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_same_pair(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test 1
    arr1 = [1, 2, 3, 4, 5, 6, 7, 8]
    arr2 = [2, 2, 3, 1, 2, 6, 7, 9]
    await run_test_case(dut, arr1, arr2)
    
    # Test 2
    arr1 = [0, 1, 2, -1, -5, 6, 0, -3, -2, 3, 4, 6, 8]
    arr2 = [2, 1, 2, -1, -5, 6, 4, -3, -2, 3, 4, 6, 8]
    # Truncate to 8 for hardware (test case has 13, spec says max 8)
    # We will test the first 8 elements or truncated list
    await run_test_case(dut, arr1[:8], arr2[:8])
    
    # Test 3
    arr1 = [2, 4, -6, -9, 11, -12, 14, -5, 17]
    arr2 = [2, 1, 2, -1, -5, 6, 4, -3, -2, 3, 4, 6, 8]
    await run_test_case(dut, arr1[:8], arr2[:8])
    
    # Test 4
    arr1 = [0, 1, 1, 2]
    arr2 = [0, 1, 2, 2]
    await run_test_case(dut, arr1, arr2)
