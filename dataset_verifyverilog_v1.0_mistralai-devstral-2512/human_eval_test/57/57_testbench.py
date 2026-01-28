import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    min_val = -(1 << (bits-1))
    max_val = (1 << (bits-1)) - 1
    if v < min_val: return min_val
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        arr_elem = getattr(dut, f'{name}')[i]
        arr_elem.value = clamp_to_width(v, width)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_monotonic(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_list, expected_result, description)
    test_cases = [
        ([1, 2, 4, 10], 1, "increasing"),
        ([1, 2, 4, 20], 1, "increasing"),
        ([1, 20, 4, 10], 0, "not monotonic"),
        ([4, 1, 0, -10], 1, "decreasing"),
        ([4, 1, 1, 0], 1, "non-strict decreasing"),
        ([1, 2, 3, 2, 5, 60], 0, "down then up"),
        ([1, 2, 3, 4, 5, 60], 1, "increasing"),
        ([9, 9, 9, 9], 1, "all equal"),
        ([5], 1, "single element"),
        ([], 1, "empty (len=0)"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 1, "full array increasing"),
        ([8, 7, 6, 5, 4, 3, 2, 1], 1, "full array decreasing")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Write array
        await write_array(dut, 'arr', inp, DATA_WIDTH)
        
        # Write length (clip to max)
        len_val = min(len(inp), ARRAY_SIZE)
        dut.len.value = len_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Verify
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            await reset_dut(dut)  # Reset before next test
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
