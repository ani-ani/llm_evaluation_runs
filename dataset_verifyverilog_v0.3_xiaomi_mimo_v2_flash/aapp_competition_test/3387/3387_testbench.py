import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
FRAC_BITS = 16
SCALE_FACTOR = 1000
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def scale_to_fixed(value):
    """Convert integer value to fixed-point representation."""
    return (value * (1 << FRAC_BITS)) // SCALE_FACTOR

def scale_from_fixed(value):
    """Convert fixed-point value back to integer scale."""
    return (value * SCALE_FACTOR) >> FRAC_BITS

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bandwidth_allocator(dut):
    """Main test function for bandwidth allocator."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (a_i, b_i, d_i, t, expected_x_i)
    test_cases = [
        # Case 1: All equal constraints
        (
            [0, 0, 0, 0],    # a_i
            [10, 10, 10, 10], # b_i
            [1, 1, 1, 1],     # d_i
            10,               # t
            [2500, 2500, 2500, 2500]  # expected (scaled) - each gets 2.5 in fixed-point
        ),
        # Case 2: Unequal constraints
        (
            [0, 2, 2, 0],    # a_i
            [1, 8, 8, 10],   # b_i
            [1000, 2, 1, 1], # d_i
            10,               # t
            [1000, 6000, 3000, 0]  # expected (scaled) - 1.0, 6.0, 3.0, 0.0
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_list, b_list, d_list, t_orig, expected_list) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: t={t_orig}")
        
        try:
            # Scale inputs
            t_scaled = scale_to_fixed(t_orig)
            a_scaled = [scale_to_fixed(a) for a in a_list]
            b_scaled = [scale_to_fixed(b) for b in b_list]
            d_scaled = [scale_to_fixed(d) for d in d_list]
            
            # Drive inputs
            dut.a0.value = a_scaled[0]
            dut.a1.value = a_scaled[1]
            dut.a2.value = a_scaled[2]
            dut.a3.value = a_scaled[3]
            
            dut.b0.value = b_scaled[0]
            dut.b1.value = b_scaled[1]
            dut.b2.value = b_scaled[2]
            dut.b3.value = b_scaled[3]
            
            dut.d0.value = d_scaled[0]
            dut.d1.value = d_scaled[1]
            dut.d2.value = d_scaled[2]
            dut.d3.value = d_scaled[3]
            
            dut.t.value = t_scaled
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read outputs
            x0 = safe_int(dut.x0.value)
            x1 = safe_int(dut.x1.value)
            x2 = safe_int(dut.x2.value)
            x3 = safe_int(dut.x3.value)
            
            # Convert back to original scale
            x0_orig = scale_from_fixed(x0)
            x1_orig = scale_from_fixed(x1)
            x2_orig = scale_from_fixed(x2)
            x3_orig = scale_from_fixed(x3)
            
            # Get expected values
            e0, e1, e2, e3 = expected_list
            
            # Allow 1% tolerance due to fixed-point rounding
            tol = 100  # 1% of 10000 scaled units
            
            def check_value(actual, expected, name):
                diff = abs(actual - expected)
                if diff > tol:
                    raise TestFailure(f"{name}: expected {expected}, got {actual}, diff={diff}")
                cocotb.log.info(f"  {name}: {actual} (expected {expected}) [OK]")
            
            check_value(x0_orig, e0, "x0")
            check_value(x1_orig, e1, "x1")
            check_value(x2_orig, e2, "x2")
            check_value(x3_orig, e3, "x3")
            
            cocotb.log.info(f"Test case {i+1}: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test case {i+1}: FAIL - {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")