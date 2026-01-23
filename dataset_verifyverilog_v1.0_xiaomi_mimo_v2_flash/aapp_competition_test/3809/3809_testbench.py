import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
MOD = 1000000007

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
    if has_signal(dut, 'start'):
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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_boat_transport(dut):
    """Test the boat_transport module with scaled-down test cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (c50, c100, k, expected_min_rides, expected_ways, description)
    # Note: min_rides=255 represents -1 (impossible)
    test_cases = [
        (1, 0, 50, 1, 1, "One 50kg person, capacity 50"),
        (2, 1, 100, 5, 2, "Two 50kg and one 100kg, capacity 100"),
        (2, 0, 50, 255, 0, "Two 50kg, capacity 50 -> impossible"),
        (1, 1, 150, 1, 1, "One 50kg and one 100kg, capacity 150"),
        (2, 1, 150, 3, 4, "Two 50kg and one 100kg, capacity 150"),
        (3, 0, 150, 5, 6, "Three 50kg, capacity 150"),
        (0, 1, 100, 1, 1, "One 100kg person, capacity 100"),
        (0, 2, 100, 255, 0, "Two 100kg, capacity 100 -> impossible"),
        (3, 3, 300, 5, 108, "Three 50kg and three 100kg, capacity 300"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (c50, c100, k, exp_rides, exp_ways, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Set inputs
        dut.c50.value = c50
        dut.c100.value = c100
        dut.k.value = k
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read outputs
        if not is_value_defined(dut.min_rides.value) or not is_value_defined(dut.ways.value):
            dut._log.error(f"Test {i+1}: Output signals undefined")
            failed += 1
            continue
        
        rides = int(dut.min_rides.value)
        ways_val = int(dut.ways.value)
        
        # Convert 255 to -1 for impossible cases
        if rides == 255:
            rides = -1
        
        # Verify
        if rides != exp_rides or ways_val != exp_ways:
            dut._log.error(f"Test {i+1} FAIL: Expected (rides={exp_rides}, ways={exp_ways}), Got (rides={rides}, ways={ways_val})")
            failed += 1
        else:
            dut._log.info(f"Test {i+1} PASS: rides={rides}, ways={ways_val}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")