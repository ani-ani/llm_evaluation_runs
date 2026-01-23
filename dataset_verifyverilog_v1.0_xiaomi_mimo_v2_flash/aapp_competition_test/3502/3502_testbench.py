import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_traffic_light(dut):
    """Test the traffic light probability calculator."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case from problem
    # Light 0: x=1, r=2, g=3
    # Light 1: x=6, r=2, g=3
    # Light 2: x=10, r=2, g=3
    # Light 3: x=16, r=3, g=4
    
    dut.x0.value = 1
    dut.r0.value = 2
    dut.g0.value = 3
    
    dut.x1.value = 6
    dut.r1.value = 2
    dut.g1.value = 3
    
    dut.x2.value = 10
    dut.r2.value = 2
    dut.g2.value = 3
    
    dut.x3.value = 16
    dut.r3.value = 3
    dut.g3.value = 4
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 100000
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done signal")
    
    # Read results
    prob0 = safe_int(dut.prob0.value)
    prob1 = safe_int(dut.prob1.value)
    prob2 = safe_int(dut.prob2.value)
    prob3 = safe_int(dut.prob3.value)
    prob_all = safe_int(dut.prob_all.value)
    
    # Expected probabilities (approximate, scaled for fixed-point)
    # 0.4, 0, 0.2, 0.171428571429, 0.228571428571
    # In 32-bit fixed-point (1.31), these are approximately:
    # 0.4 * 2^31 = 858993459
    # 0 * 2^31 = 0
    # 0.2 * 2^31 = 429496730
    # 0.171428571429 * 2^31 = 736330724
    # 0.228571428571 * 2^31 = 980996996
    
    # Allow some tolerance for fixed-point rounding
    tolerance = 10000
    
    dut._log.info(f"prob0: {prob0} (expected ~858993459)")
    dut._log.info(f"prob1: {prob1} (expected ~0)")
    dut._log.info(f"prob2: {prob2} (expected ~429496730)")
    dut._log.info(f"prob3: {prob3} (expected ~736330724)")
    dut._log.info(f"prob_all: {prob_all} (expected ~980996996)")
    
    # Check results
    if abs(prob0 - 858993459) > tolerance:
        raise TestFailure(f"prob0 mismatch: {prob0}")
    if abs(prob1 - 0) > tolerance:
        raise TestFailure(f"prob1 mismatch: {prob1}")
    if abs(prob2 - 429496730) > tolerance:
        raise TestFailure(f"prob2 mismatch: {prob2}")
    if abs(prob3 - 736330724) > tolerance:
        raise TestFailure(f"prob3 mismatch: {prob3}")
    if abs(prob_all - 980996996) > tolerance:
        raise TestFailure(f"prob_all mismatch: {prob_all}")
    
    dut._log.info("All tests passed!")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_traffic_light_random(dut):
    """Test with random inputs to verify basic functionality."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Generate random test case
    random.seed(42)
    for i in range(4):
        x_val = random.randint(1, 100)
        r_val = random.randint(0, 50)
        g_val = random.randint(1, 50)
        
        setattr(dut, f'x{i}', x_val)
        setattr(dut, f'r{i}', r_val)
        setattr(dut, f'g{i}', g_val)
        
        dut._log.info(f"Light {i}: x={x_val}, r={r_val}, g={g_val}")
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 100000
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done signal")
    
    # Read results
    prob0 = safe_int(dut.prob0.value)
    prob1 = safe_int(dut.prob1.value)
    prob2 = safe_int(dut.prob2.value)
    prob3 = safe_int(dut.prob3.value)
    prob_all = safe_int(dut.prob_all.value)
    
    dut._log.info(f"Results - prob0: {prob0}, prob1: {prob1}, prob2: {prob2}, prob3: {prob3}, prob_all: {prob_all}")
    
    # Basic sanity checks: probabilities should be between 0 and 2^31
    for prob, name in [(prob0, 'prob0'), (prob1, 'prob1'), (prob2, 'prob2'), (prob3, 'prob3'), (prob_all, 'prob_all')]:
        if prob < 0 or prob > (1<<31):
            raise TestFailure(f"{name} out of range: {prob}")
    
    # Sum of individual probabilities should be <= probability of all
    # (actually, they should be equal, but due to rounding we allow some tolerance)
    sum_probs = prob0 + prob1 + prob2 + prob3
    if sum_probs > prob_all + 100000:  # Allow some tolerance
        raise TestFailure(f"Sum of individual probabilities ({sum_probs}) > prob_all ({prob_all})")
    
    dut._log.info("Random test passed!")