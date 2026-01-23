import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 12          # For outputs
CLK_PERIOD_NS = 10
MAX_CYCLES = 50000       # Enough for all computations

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_golden_circle(dut):
    """Test the golden_circle module with various inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to compute expected min and max stops
    def compute_expected(n, k, a, b):
        nk = n * k
        mn = 10**15
        mx = -1
        for i in range(n):
            # Four combinations: (s=a, next=i*k±b) and (s=k-a, next=i*k±b)
            for s_pos in [a, k - a]:
                for next_offset in [b, -b]:
                    next_pos = i * k + next_offset
                    l = (next_pos - s_pos) % nk
                    if l == 0:
                        turns = 1
                    else:
                        g = math.gcd(nk, l)
                        turns = nk // g
                    mn = min(mn, turns)
                    mx = max(mx, turns)
        return mn, mx
    
    # Test cases: (n, k, a, b)
    test_cases = [
        (2, 3, 1, 1),   # Example 1
        (3, 2, 0, 0),   # Example 2
        (1, 10, 5, 3),  # Example 3
        (3, 3, 1, 0),   # Additional
        (4, 3, 1, 1),   # Additional
        (5, 5, 2, 2),   # Additional
        (6, 3, 1, 1),   # Additional
        (3, 10, 1, 3),  # Additional
    ]
    
    passed = 0
    failed = 0
    
    for (n, k, a, b) in test_cases:
        # Scale down if needed (our design fits already)
        if n > 16 or k > 256:
            dut._log.warning(f"Skipping case n={n}, k={k} (exceeds scaled limits)")
            continue
        
        dut._log.info(f"Testing n={n}, k={k}, a={a}, b={b}")
        
        # Compute expected
        exp_min, exp_max = compute_expected(n, k, a, b)
        
        # Drive inputs
        dut.n.value = n
        dut.k.value = k
        dut.a.value = a
        dut.b.value = b
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read results
        min_val = safe_int(dut.min_stops.value)
        max_val = safe_int(dut.max_stops.value)
        
        # Compare
        if min_val != exp_min or max_val != exp_max:
            dut._log.error(f"FAIL: expected ({exp_min}, {exp_max}), got ({min_val}, {max_val})")
            failed += 1
        else:
            dut._log.info(f"PASS: min={min_val}, max={max_val}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")