import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# Q8.8 fixed-point conversion
FP_BITS = 16
FRAC_BITS = 8

def float_to_fixed(f):
    """Convert float to Q8.8 fixed-point integer."""
    return int(f * (1 << FRAC_BITS))

def fixed_to_float(fixed):
    """Convert Q8.8 fixed-point integer to float."""
    return fixed / (1 << FRAC_BITS)

# Helper functions
def is_value_defined(value):
    """Check if cocotb value is defined."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    """Check if DUT has a signal."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut, n):
    """Start computation with given n."""
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_harmonic_sum(dut):
    """Test harmonic sum module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, expected_harmonic_sum)
    test_cases = [
        (7, 2.5928571428571425),
        (4, 2.083333333333333),
        (19, 3.547739657143682),
    ]
    
    passed = 0
    failed = 0
    
    for n, expected in test_cases:
        cocotb.log.info(f"Test: harmonic_sum({n}) = {expected}")
        
        try:
            # Start computation
            await start_computation(dut, n)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fp = int(dut.result.value)
            result_float = fixed_to_float(result_fp)
            
            # Check with tolerance
            rel_error = abs(result_float - expected) / expected
            
            if rel_error > 0.01:  # 1% tolerance for fixed-point
                raise TestFailure(
                    f"Expected {expected:.6f}, got {result_float:.6f} "
                    f"(error: {rel_error:.4f}, fixed-point: 0x{result_fp:04X})"
                )
            
            cocotb.log.info(f"  PASS: {result_float:.6f} (0x{result_fp:04X})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")