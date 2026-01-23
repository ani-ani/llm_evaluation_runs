import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_tuples(dut, tup1, tup2, length):
    """Write tuple values to individual ports"""
    tup1_full = list(tup1) + [0] * (MAX_SIZE - len(tup1))
    tup2_full = list(tup2) + [0] * (MAX_SIZE - len(tup2))
    
    for i in range(MAX_SIZE):
        if has_signal(dut, f'tup1_{i}'):
            getattr(dut, f'tup1_{i}').value = tup1_full[i]
        if has_signal(dut, f'tup2_{i}'):
            getattr(dut, f'tup2_{i}').value = tup2_full[i]
    
    if has_signal(dut, 'len'):
        dut.len.value = length

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tuple_comparator(dut):
    """Test tuple comparison function"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (tup1, tup2, expected_result, description)
    test_cases = [
        ((1, 2, 3), (2, 3, 4), False, "Test 1: (1,2,3) vs (2,3,4) - all larger"),
        ((4, 5, 6), (3, 4, 5), True, "Test 2: (4,5,6) vs (3,4,5) - all smaller"),
        ((11, 12, 13), (10, 11, 12), True, "Test 3: (11,12,13) vs (10,11,12) - all smaller"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (tup1, tup2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            length = len(tup1)
            
            # Write tuples
            await write_tuples(dut, tup1, tup2, length)
            await Timer(10, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = bool(int(dut.result.value))
            
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
