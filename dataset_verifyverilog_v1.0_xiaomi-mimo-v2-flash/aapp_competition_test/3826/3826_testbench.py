import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 8, 10, 500

# MANDATORY HELPERS
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

# ARRAY ACCESS - CRITICAL: Individual element assignment
def write_array(dut, name, vals, width):
    """Write array values to individual ports or array elements"""
    for i, v in enumerate(vals):
        if has_signal(dut, f'{name}_{i}'):
            getattr(dut, f'{name}_{i}').value = clamp_to_width(v, width)
        else:
            dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_subsegment_removal(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_array, expected_result, description)
    test_cases = [
        ([1, 2, 3], 0, "Already distinct"),
        ([1, 1, 2, 2], 2, "Remove middle duplicate"),
        ([1, 4, 1, 4, 9], 2, "Two possible removals"),
        ([1, 2, 1, 2, 1, 2], 2, "Pattern duplicate"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 0, "Full 8 distinct"),
        ([1, 1, 1, 1, 1, 1, 1, 1], 1, "All identical"),
        ([5, 5, 3, 3, 5, 3], 2, "Mixed duplicates"),
        ([1, 2, 3, 1, 4, 5], 1, "Single duplicate at end"),
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp}")
        try:
            # Limit to max array size
            test_input = inp[:ARRAY_SIZE]
            exp = min(exp, ARRAY_SIZE)
            
            # Write array
            await write_array(dut, 'arr', test_input, DATA_WIDTH)
            dut.len.value = len(test_input)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                await RisingEdge(dut.clk)  # Ensure result is stable
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Verify result
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            cocotb.log.info(f"  PASS: Result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTotal: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")
