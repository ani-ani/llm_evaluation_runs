import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_spaceship_destroyer(dut):
    """Test the spaceship_destroyer module with scaled-down inputs."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (g1_0, g1_1, g2_0, g2_1, n, m, expected)
    test_cases = [
        # Example 1: Should destroy 4 ships
        (1, 2, 3, 4, 2, 2, 4),
        # Example 2: All zeros
        (0, 0, 0, 0, 2, 2, 4),
        # Single ships
        (5, 0, 5, 0, 1, 1, 2),
        # Mixed
        (1, 3, 2, 4, 2, 2, 4),
    ]
    
    for idx, (g1_0, g1_1, g2_0, g2_1, n, m, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {idx+1}: g1=[{g1_0},{g1_1}] g2=[{g2_0},{g2_1}] n={n} m={m} expected={expected}")
        
        # Set inputs
        dut.group1_0.value = g1_0
        dut.group1_1.value = g1_1
        dut.group2_0.value = g2_0
        dut.group2_1.value = g2_1
        dut.n.value = n
        dut.m.value = m
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {idx+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"Test {idx+1} passed: result = {result}")
        
        # Wait for a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")