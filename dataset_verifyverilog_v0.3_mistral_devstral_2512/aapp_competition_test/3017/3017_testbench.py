import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

# ============================================================================
# TEST CASES
# ============================================================================

test_cases = [
    (1000000, 1, 468559),
    (1000000, 5, 49401),
    (1000000, 16, 20),
    (9000000000000000000, 62, 1),
    (5432123456789876543, 33, 4842258985),
]

# ============================================================================
# HELPER: Convert n to 19-digit BCD array
# ============================================================================

def n_to_digits(n):
    """Convert integer n to list of 19 BCD digits (most significant first)."""
    s = str(n).zfill(19)  # Pad to 19 digits
    return [int(c) for c in s]  # List of 19 digits

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_count_numbers_with_substring(dut):
    """Test the count_numbers_with_substring module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for n, e, expected in test_cases:
        dut._log.info(f"Test: n={n}, e={e}, expected={expected}")
        
        # Convert n to digits
        digits = n_to_digits(n)
        
        # Set n_digits inputs
        for i in range(19):
            if has_signal(dut, f'n_digits_{i}'):
                getattr(dut, f'n_digits_{i}').value = digits[i]
            else:
                # Fallback to indexed array
                if has_signal(dut, 'n_digits'):
                    dut.n_digits[i].value = digits[i]
                else:
                    raise TestFailure("Cannot find n_digits input")
        
        # Set e
        dut.e.value = e
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        done_timeout = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            done_timeout += 1
            if done_timeout > 10000:
                raise TestFailure(f"Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.count.value):
            raise TestFailure(f"Result count is undefined")
        
        result = int(dut.count.value)
        
        if result == expected:
            dut._log.info(f"  PASS: got {result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")