import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Include helpers
def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_hearing_dp(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Define Q format
    Q = 16
    SCALE = 1 << Q
    
    # Test Case 1: Example from prompt
    # Input: 4 hearings
    # 1 1 7
    # 3 2 3
    # 5 1 4
    # 6 10 10
    # Expected: 2.125
    
    hearings = [
        (1, 1, 7),
        (3, 2, 3),
        (5, 1, 4),
        (6, 10, 10)
    ]
    
    # Expected result 2.125 * 65536 = 139264
    expected_val = int(2.125 * SCALE)
    
    n = len(hearings)
    
    # Start loading
    dut.start.value = 1
    dut.n.value = n
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed hearings sequentially
    # In the spec, we assumed 'start' triggers load, then data flows or waits.
    # Let's assume we write data into 's_in', 'a_in', 'b_in' ports while 'start' is low
    # or a specific 'load' signal. The prompt says 'n' and inputs are valid at start or after.
    # Let's assume we need to write 'n' words after the start pulse.
    
    for i in range(n):
        s, a, b = hearings[i]
        # Clamp inputs if necessary (assuming 16-bit inputs as per spec)
        dut.s_in.value = clamp_to_width(s, 16)
        dut.a_in.value = clamp_to_width(a, 16)
        dut.b_in.value = clamp_to_width(b, 16)
        await RisingEdge(dut.clk)
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    result_raw = int(dut.result.value)
    
    # Convert back to float for comparison
    result_float = result_raw / SCALE
    
    # Allow error
    error = abs(result_float - 2.125)
    if error > 0.002:  # Allow slight tolerance
        raise TestFailure(f"Expected 2.125, got {result_float} (diff {error})")
    
    cocotb.log.info(f"Test 1 Passed: Result {result_float}")
    
    # Test Case 2: Second example
    # 5 hearings
    # 1 1 7
    # 1 1 6
    # 3 2 3
    # 5 1 4
    # 6 10 10
    # Expected: 2.29166667
    
    await reset_dut(dut)
    
    hearings2 = [
        (1, 1, 7),
        (1, 1, 6),
        (3, 2, 3),
        (5, 1, 4),
        (6, 10, 10)
    ]
    expected_val2 = int(2.29166667 * SCALE)
    n2 = len(hearings2)
    
    dut.start.value = 1
    dut.n.value = n2
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(n2):
        s, a, b = hearings2[i]
        dut.s_in.value = clamp_to_width(s, 16)
        dut.a_in.value = clamp_to_width(a, 16)
        dut.b_in.value = clamp_to_width(b, 16)
        await RisingEdge(dut.clk)
    
    await wait_for_done(dut)
    
    result_raw2 = int(dut.result.value)
    result_float2 = result_raw2 / SCALE
    
    error2 = abs(result_float2 - 2.29166667)
    if error2 > 0.002:
        raise TestFailure(f"Expected 2.29166667, got {result_float2} (diff {error2})")
        
    cocotb.log.info(f"Test 2 Passed: Result {result_float2}")