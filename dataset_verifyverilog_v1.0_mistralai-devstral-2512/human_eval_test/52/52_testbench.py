import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions

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

# Testbench constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        getattr(dut, name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_below_threshold(dut):
    # Check if sequential module
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: still need some timing
        await Timer(1, units='ns')
    
    # Test cases: (array, threshold, expected_result, description)
    test_cases = [
        ([1, 2, 4, 10, 0, 0, 0, 0], 100, True, "All below large threshold"),
        ([1, 20, 4, 10, 0, 0, 0, 0], 5, False, "20 > 5"),
        ([1, 20, 4, 10, 0, 0, 0, 0], 21, True, "All below 21"),
        ([1, 20, 4, 10, 0, 0, 0, 0], 22, True, "All below 22"),
        ([1, 8, 4, 10, 0, 0, 0, 0], 11, True, "All below 11"),
        ([1, 8, 4, 10, 0, 0, 0, 0], 10, False, "10 not < 10"),
    ]
    
    passed = failed = 0
    
    for i, (arr, threshold, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            await write_array(dut, 'arr', arr, DATA_WIDTH)
            dut.threshold.value = clamp_to_width(threshold, DATA_WIDTH)
            
            if is_seq:
                # Sequential operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # Combinational
                await Timer(1, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            
            expected_val = 1 if expected else 0
            if result != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")