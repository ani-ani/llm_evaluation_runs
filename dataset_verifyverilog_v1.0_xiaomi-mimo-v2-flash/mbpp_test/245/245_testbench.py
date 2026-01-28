import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
RESULT_WIDTH = 16
LEN_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

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
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_max_bitonic_subsequence(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        ([1, 15, 51, 45, 33, 100, 12, 18, 9], 194, "Test 1"),
        ([80, 60, 30, 40, 20, 10], 210, "Test 2"),
        ([2, 3, 14, 16, 21, 23, 29, 30], 138, "Test 3")
    ]
    
    passed = failed = 0
    
    for i, (arr_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                # Write input array
                write_array(dut, 'arr', arr_vals, DATA_WIDTH)
                dut.len.value = len(arr_vals)
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                    
                result = safe_int(dut.result.value)
                # Convert from unsigned if needed
                if has_signal(dut, 'result'):
                    try:
                        raw_val = int(dut.result.value)
                        # Check if result is signed (negative in Python)
                        if result >= (1 << (RESULT_WIDTH - 1)):
                            result = result - (1 << RESULT_WIDTH)
                    except ValueError:
                        raise TestFailure("Cannot read result")
            else:
                # Combinational
                write_array(dut, 'arr', arr_vals, DATA_WIDTH)
                dut.len.value = len(arr_vals)
                await Timer(100, units='ns')
                result = safe_int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            cocotb.log.info(f"  PASS: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")