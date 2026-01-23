import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_PAIRS = 8
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
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def feed_input(dut, pairs):
    """Feed pairs into the input arrays."""
    for i, (a, b) in enumerate(pairs):
        dut.arr_a[i].value = a
        dut.arr_b[i].value = b
    dut.valid_pairs.value = len(pairs)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_bidirectional(dut):
    """Test bidirectional pair counting."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([(5, 6), (1, 2), (6, 5), (9, 1), (6, 5), (2, 1)], 3, "Test 1: 3 bidirectional pairs"),
        ([(5, 6), (1, 3), (6, 5), (9, 1), (6, 5), (2, 1)], 2, "Test 2: 2 bidirectional pairs"),
        ([(5, 6), (1, 2), (6, 5), (9, 2), (6, 5), (2, 1)], 4, "Test 3: 4 bidirectional pairs"),
        ([(1, 2)], 0, "Edge case: single pair"),
        ([(1, 2), (2, 1)], 1, "Edge case: two bidirectional"),
        ([(1, 1), (1, 1), (1, 1)], 3, "Edge case: self-bidirectional"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (pairs, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Running {description}")
        
        try:
            # Feed input
            await feed_input(dut, pairs)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: {result}")
            passed += 1
            
            # Wait for done to go low before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset between tests
            await reset_dut(dut)
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")