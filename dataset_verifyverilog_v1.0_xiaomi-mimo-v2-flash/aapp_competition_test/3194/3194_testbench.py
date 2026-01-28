import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants
CLK_NS = 10
MAX_CYCLES = 200
MAX_N = 8
DATA_WIDTH = 16

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_inputs(dut, n, t, a_list, b_list):
    """Write inputs to DUT with proper scaling"""
    dut.n.value = clamp_to_width(n, 4)
    dut.t.value = clamp_to_width(t, 6)
    
    # Write arrays element by element
    for i in range(MAX_N):
        a_val = a_list[i] if i < n else 0
        b_val = b_list[i] if i < n else 0
        dut.a[i].value = clamp_to_width(a_val, DATA_WIDTH)
        dut.b[i].value = clamp_to_width(b_val, DATA_WIDTH)

async def run_test_case(dut, n, t, a_list, b_list, expected):
    """Run a single test case"""
    # Write inputs
    await write_inputs(dut, n, t, a_list, b_list)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    result = int(dut.result.value)
    
    return result == expected

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_photograph_scheduling(dut):
    """Test photograph scheduling algorithm"""
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (n, t, a_list, b_list, expected_result)
    test_cases = [
        # Sample 1: n=2, t=10, [0,15], [5,20] -> yes (0-10, 10-20)
        (2, 10, [0, 5], [15, 20], 1),
        # Sample 2: n=2, t=10, [1,15], [0,20] -> no (1-11, 0-10 overlap)
        (2, 10, [1, 0], [15, 20], 0),
        # Sample 3: n=2, t=10, [5,10], [30,20] -> yes (5-15, 20-30)
        (2, 10, [5, 10], [30, 20], 1),
        # Edge case: n=1, t=1, [0,1] -> yes
        (1, 1, [0], [1], 1),
        # Edge case: n=0 -> yes (vacuously)
        (0, 0, [], [], 1),
        # No overlap possible: n=3, t=5, [0,10,20], [10,20,30] -> yes
        (3, 5, [0, 10, 20], [10, 20, 30], 1),
        # Impossible: n=3, t=5, [0,5,10], [10,15,20] -> no (0-5, 5-10, 10-15 overlaps)
        (3, 5, [0, 5, 10], [10, 15, 20], 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, t, a_list, b_list, expected) in enumerate(test_cases):
        # Pad lists if necessary
        if len(a_list) < MAX_N:
            a_list = a_list + [0] * (MAX_N - len(a_list))
        if len(b_list) < MAX_N:
            b_list = b_list + [0] * (MAX_N - len(b_list))
        
        desc = f"n={n}, t={t}, exp={'yes' if expected else 'no'}"
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            result = await run_test_case(dut, n, t, a_list, b_list, expected)
            if not result:
                raise TestFailure(f"Expected {'yes' if expected else 'no'}, got {'yes' if int(dut.result.value) else 'no'}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_random_cases(dut):
    """Test with random valid inputs"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    random.seed(42)
    passed = 0
    failed = 0
    
    for test_id in range(5):
        # Generate random test case
        n = random.randint(0, 8)
        t = random.randint(1, 32)
        
        a_list = []
        b_list = []
        
        # Generate n intervals
        intervals = []
        for _ in range(n):
            a = random.randint(0, 65530)
            b = random.randint(a + 1, 65535)
            intervals.append((a, b))
        
        # Sort by end time for golden reference
        intervals.sort(key=lambda x: x[1])
        
        for a, b in intervals:
            a_list.append(a)
            b_list.append(b)
        
        # Compute expected result (Python golden reference)
        current_time = 0
        possible = True
        for a, b in sorted(intervals, key=lambda x: x[1]):
            start = max(current_time, a)
            if start + t > b:
                possible = False
                break
            current_time = start + t
        
        expected = 1 if possible else 0
        
        # Pad lists
        if len(a_list) < MAX_N:
            a_list = a_list + [0] * (MAX_N - len(a_list))
        if len(b_list) < MAX_N:
            b_list = b_list + [0] * (MAX_N - len(b_list))
        
        desc = f"Random {test_id+1}: n={n}, t={t}"
        cocotb.log.info(f"Test {desc}")
        
        try:
            result = await run_test_case(dut, n, t, a_list, b_list, expected)
            if not result:
                raise TestFailure(f"Expected {'yes' if expected else 'no'}, got {'yes' if int(dut.result.value) else 'no'}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} random tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} random tests passed")