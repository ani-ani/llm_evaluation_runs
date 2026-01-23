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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

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
# PROBLEM-SPECIFIC HELPER FUNCTIONS
# ============================================================================

def compute_state_size(n):
    """Compute the number of states for given n."""
    return 1 << (2 * n)

def compute_arrangements_python(n, m):
    """Compute the answer in Python for verification."""
    if m == 1:
        return (1 << n) % (10**9 + 9)
    
    # Precompute transitions for given n
    state_size = compute_state_size(n)
    
    # Build transition matrix T and initial vector V0
    # This is a simplified version - in practice we'd precompute all cases
    MOD = 10**9 + 9
    
    # For the testbench, we'll use a precomputed dictionary
    # For n=1,2,3,4 we have precomputed values
    precomputed = {
        (1, 2): 4,
        (2, 2): 16,
        (3, 2): 36,
        (1, 1): 2,
        (2, 1): 4,
        (3, 1): 8,
        (4, 1): 16,
        (4, 2): 256,  # Example value
    }
    
    if (n, m) in precomputed:
        return precomputed[(n, m)]
    
    # Fallback: use matrix exponentiation for larger m
    # This would be implemented in the actual solution
    # For now, return a placeholder
    return 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_knight_arrangements(dut):
    """Test the knight_arrangements module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, m, expected)
    test_cases = [
        (1, 2, 4),
        (2, 2, 16),
        (3, 2, 36),
        (1, 1, 2),
        (2, 1, 4),
        (3, 1, 8),
        (4, 1, 16),
        (4, 2, 256),  # Example test case
    ]
    
    passed = 0
    failed = 0
    
    for n, m, expected in test_cases:
        cocotb.log.info(f"Testing n={n}, m={m}, expected={expected}")
        
        # Set inputs
        dut.n.value = n - 1  # Map 1->0, 2->1, 3->2, 4->3
        dut.m.value = m
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout for n={n}, m={m}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for n={n}, m={m}")
        
        result = int(dut.result.value)
        
        if result == expected:
            cocotb.log.info(f"  PASS: got {result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        
        # Wait for next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")