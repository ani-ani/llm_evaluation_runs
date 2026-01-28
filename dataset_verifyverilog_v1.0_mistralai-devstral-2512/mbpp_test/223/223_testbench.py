import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

async def write_array(dut, name, vals, width):
    """Write individual array elements (not dut.arr.value = list)"""
    for i in range(ARRAY_SIZE):
        if i < len(vals):
            getattr(dut, f"{name}_{i}").value = clamp_to_width(vals[i], width)
        else:
            getattr(dut, f"{name}_{i}").value = 0

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_majority_checker(dut):
    # Check if sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: no clock
        await Timer(100, units='ns')
    
    # Test cases based on Python examples
    test_cases = [
        # (arr, n, target, expected_result, description)
        ([1, 2, 3, 3, 3, 3, 10], 7, 3, 1, "Test 1: majority element at end"),
        ([1, 1, 2, 4, 4, 4, 6, 6], 8, 4, 0, "Test 2: element appears 3/8 (not majority)"),
        ([1, 1, 1, 2, 2], 5, 1, 1, "Test 3: majority element at start"),
        ([1, 1, 2, 2], 4, 1, 0, "Test 4: equal count, no majority"),
        ([5], 1, 5, 1, "Test 5: single element majority"),
        ([2, 2], 2, 2, 1, "Test 6: two identical elements"),
        ([1, 2, 3], 3, 1, 0, "Test 7: not majority"),
        ([0, 0, 0, 0, 0], 5, 0, 1, "Test 8: all same element"),
        ([1, 2, 3, 4, 5], 5, 3, 0, "Test 9: middle element not majority"),
        ([10, 20, 30, 30, 30, 30, 30], 7, 30, 1, "Test 10: clear majority"),
        ([5, 5, 5, 6, 6, 6, 6], 7, 6, 1, "Test 11: near majority edge"),
        ([1, 1, 2, 2, 3, 3], 6, 2, 0, "Test 12: all pairs"),
        ([1], 0, 1, 0, "Test 13: empty array"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 16, 9, 0, "Test 14: max length, no majority"),
        ([255]*16, 16, 255, 1, "Test 15: all max value, majority"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, n, target, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            await write_array(dut, 'arr', arr, DATA_WIDTH)
            dut.target.value = clamp_to_width(target, DATA_WIDTH)
            dut.len.value = clamp_to_width(n, 4)  # 4-bit width for length
            
            if is_seq:
                # Sequential operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # Combinational: result should be immediate
                await Timer(10, units='ns')
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")
