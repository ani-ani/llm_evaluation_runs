import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

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

def popcount(x):
    return bin(x).count('1')

def sort_expected(arr):
    """Sort by (popcount, value) ascending"""
    return sorted(arr, key=lambda x: (popcount(x), x))

async def write_array(dut, vals):
    """Write array values to HDL ports"""
    for i in range(min(len(vals), ARRAY_SIZE)):
        dut.arr[i].value = clamp_to_width(vals[i], DATA_WIDTH)
    for i in range(len(vals), ARRAY_SIZE):
        dut.arr[i].value = 0

async def read_array(dut):
    """Read result array from HDL ports"""
    result = []
    for i in range(ARRAY_SIZE):
        v = safe_int(dut.result[i].value, 0)
        result.append(v)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sort_array_by_popcount(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([1, 5, 2, 3, 4], [1, 2, 3, 4, 5]),
        ([1, 0, 2, 3, 4], [0, 1, 2, 3, 4]),
        ([2, 4, 8, 16, 32], [2, 4, 8, 16, 32]),
        ([], []),
        ([2, 5, 77, 4, 5, 3, 5, 7, 2, 3, 4], [2, 2, 4, 4, 3, 3, 5, 5, 5, 7, 77]),
        ([3, 6, 44, 12, 32, 5], [32, 3, 5, 6, 12, 44]),
        ([2, 4, 8, 16, 32], [2, 4, 8, 16, 32]),
        ([255, 127, 63, 31, 15, 7, 3, 1], [1, 3, 7, 15, 31, 63, 127, 255]),  # Popcount test
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input={inp}")
        try:
            # Pad input to array size
            padded_input = inp + [0] * (ARRAY_SIZE - len(inp))
            
            if is_seq:
                # Write input
                await write_array(dut, padded_input)
                
                # Start sorting
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                result = await read_array(dut)
                actual = result[:len(expected)]
            else:
                # Combinational
                await write_array(dut, padded_input)
                await Timer(100, units='ns')
                result = await read_array(dut)
                actual = result[:len(expected)]
            
            # Check
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")