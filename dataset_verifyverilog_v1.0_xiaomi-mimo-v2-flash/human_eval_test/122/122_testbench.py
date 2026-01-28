import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
MAX_ARRAY = 16
CLK_NS = 10
MAX_CYCLES = 100

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_add_elements(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module requires clock for sequential operation")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([1,-2,-3,41,57,76,87,88,99], 3, -4, "simple with negatives"),
        ([111,121,3,4000,5,6], 2, 0, "no valid elements"),
        ([11,21,3,90,5,6,7,8,9], 4, 125, "all two-digit"),
        ([111,21,3,4000,5,6,7,8,9], 4, 24, "mixed three-digit"),
        ([1], 1, 1, "single element"),
        ([100, 99, 1, -99, -100, 50], 6, 99+1-99+50, "edge boundaries"),
        ([-100, -99, 0, 99, 100], 5, -99+0+99, "negative boundaries"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, k, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - arr={arr}, k={k}")
        try:
            # Write array elements
            for idx in range(MAX_ARRAY):
                if idx < len(arr):
                    val = from_signed(arr[idx], DATA_WIDTH)
                else:
                    val = 0
                dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
            
            # Write k
            dut.k.value = k
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_raw = int(dut.result.value)
            result = to_signed(result_raw, 18)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")