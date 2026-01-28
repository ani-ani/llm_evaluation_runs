import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
LEN_WIDTH = 4
RESULT_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 150

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i < ARRAY_SIZE:
            arr_elem = getattr(dut, name)[i]
            arr_elem.value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sum_non_repeated(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases from problem
    test_cases = [
        ([1,2,3,1,1,4,5,6], 8, 21, "Basic case 1"),
        ([1,10,9,4,2,10,10,45], 8, 57, "Basic case 2 (first 8 elements)"),
        ([12,10,9,45,2,10,10,45], 8, 80, "Basic case 3 (first 8 elements)"),
        ([], 0, 0, "Empty array"),
        ([5], 1, 5, "Single element"),
        ([1,2,3,4,5,6,7,8], 8, 36, "All unique"),
        ([1,1,1,1,1,1,1,1], 8, 1, "All same (8 elements, count=8, not unique)"),
        ([5,5,5,5,5,5,5,5], 8, 5, "All same 5s"),
        ([1,1,2,2,3,3,4,4], 8, 0, "All pairs"),
        ([1,1,2,3,4,5,6,7], 8, 27, "Mixed with duplicates"),
        ([255,254,253,252,251,250,249,248], 8, 2028, "Max values"),
        ([1,2,3,4,5], 5, 15, "Partial fill 1"),
        ([1,1,2,2,3], 5, 3, "Partial fill 2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {input_vals}, Expected: {expected}")
        try:
            # Write inputs
            if is_seq:
                await write_array(dut, 'arr', input_vals, DATA_WIDTH)
                dut.len.value = length
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational
                await write_array(dut, 'arr', input_vals, DATA_WIDTH)
                dut.len.value = length
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: got {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")