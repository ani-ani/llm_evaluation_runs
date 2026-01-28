import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sorted_train(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, permutation, expected_moves)
    test_cases = [
        (5, [4,1,2,5,3], 2),
        (4, [4,1,3,2], 2),
        (1, [1], 0),
        (2, [1,2], 0),
        (2, [2,1], 1),
        (6, [5,3,6,1,4,2], 4),
        (3, [1,2,3], 0),
        (3, [1,3,2], 1),
        (3, [2,1,3], 1),
        (3, [3,1,2], 1),
        (3, [3,2,1], 2),
        (5, [1,4,2,3,5], 2),
    ]
    
    passed = 0
    failed = 0
    
    for case_idx, (n, perm, expected) in enumerate(test_cases):
        if n > ARRAY_SIZE:
            cocotb.log.warning(f"Skipping test with n={n} > ARRAY_SIZE={ARRAY_SIZE}")
            continue
            
        cocotb.log.info(f"Test {case_idx+1}: n={n}, perm={perm}, expected={expected}")
        
        try:
            # Set inputs
            dut.n.value = n
            for i in range(ARRAY_SIZE):
                if i < n:
                    dut.p[i].value = clamp_to_width(perm[i], DATA_WIDTH)
                else:
                    dut.p[i].value = 0
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")