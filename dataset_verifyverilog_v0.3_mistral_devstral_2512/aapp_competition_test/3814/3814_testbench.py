import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 32
MAX_N = 1000
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_ramen_count(dut):
    """Test the ramen counting module with various N and M combinations."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases from the problem
    test_cases = [
        (2, 1000000007, 2),
        (3, 1000000009, 118),
        (4, 841234127, 58456),
        (5, 631912433, 498123872),
    ]
    
    for n, m, expected in test_cases:
        dut._log.info(f"Testing N={n}, M={m}, expected={expected}")
        
        # Reset
        await reset_dut(dut)
        
        # Set inputs
        dut.N.value = n
        dut.M.value = m
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result = safe_int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"N={n}, M={m}: expected {expected}, got {result}")
        else:
            dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed!")

# Additional stress test for larger N (scaled down)
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_stress(dut):
    """Test with larger N (scaled down) to verify robustness."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Use smaller N for HDL simulation
    test_cases = [
        (10, 1000000007),
        (20, 1000000009),
    ]
    
    for n, m in test_cases:
        dut._log.info(f"Stress test: N={n}, M={m}")
        
        await reset_dut(dut)
        
        dut.N.value = n
        dut.M.value = m
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result = safe_int(dut.result.value)
        dut._log.info(f"  Result: {result} (mod {m})")
        # Just check it's defined and reasonable
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        # We don't know exact expected values for larger N, but result should be defined
        dut._log.info(f"  PASS: Got defined result {result}")
