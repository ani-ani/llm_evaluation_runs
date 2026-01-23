import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_DAYS = 16
MAX_WORKERS = 8
DATA_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hr_optimization(dut):
    """Test HR optimization module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases - scaled down versions
    # Format: (days: list of (f_i, h_i), expected_min_hr, description)
    test_cases = [
        (
            [(0, 3), (1, 1), (2, 1), (2, 0)] + [(0, 0)] * 12,
            3,
            "Sample 1: 4 days with operations, rest idle"
        ),
        (
            [(0, 8), (0, 8), (2, 0), (0, 0), (0, 8), (8, 8)] + [(0, 0)] * 10,
            2,
            "Scaled Sample 2: 6 days with operations, rest idle"
        ),
        (
            [(0, 1), (1, 1), (0, 1), (1, 0)] + [(0, 0)] * 12,
            2,
            "Simple alternating pattern"
        ),
        (
            [(0, 8)] * 16,
            1,
            "All hiring, no firing"
        ),
        (
            [(0, 1), (0, 1), (0, 1), (0, 1), (0, 1), (0, 1), (0, 1), (0, 1)] + [(0, 0)] * 8,
            1,
            "8 hires then idle"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (days, expected_min_hr, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {test_idx + 1}: {description}")
        
        try:
            # Reset for each test
            await reset_dut(dut)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed days one by one
            for day_idx, (f_i, h_i) in enumerate(days):
                # Wait for module to be ready for next day (optional)
                await Timer(10, units='ns')
                
                # Set inputs
                dut.day_index.value = day_idx
                dut.f_i.value = clamp_to_width(f_i, DATA_WIDTH)
                dut.h_i.value = clamp_to_width(h_i, DATA_WIDTH)
                
                await RisingEdge(dut.clk)
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=500)
            
            # Read results
            if not is_value_defined(dut.min_hr.value):
                raise TestFailure("min_hr is undefined (X/Z)")
            
            actual_min_hr = int(dut.min_hr.value)
            
            if actual_min_hr != expected_min_hr:
                raise TestFailure(f"Expected min_hr={expected_min_hr}, got {actual_min_hr}")
            
            dut._log.info(f"  PASS: min_hr = {actual_min_hr}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
