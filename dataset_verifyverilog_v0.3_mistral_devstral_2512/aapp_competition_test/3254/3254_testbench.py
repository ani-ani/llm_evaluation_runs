import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
P_WIDTH = 13
COUNT_WIDTH = 8
MAX_N = 256
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# COMPUTE SOLUTION IN PYTHON
# ============================================================================
import math

def compute_solution(P_scaled):
    """Return (a1,a2,a3,a4,a5) for given P_scaled."""
    g = math.gcd(P_scaled, 1000)
    n = 1000 // g
    S = (P_scaled * n) // 1000
    # Search for a5, a4, a3, a2, a1
    for a5 in range(min(S//5, n), -1, -1):
        for a4 in range(min((S - 5*a5)//4, n - a5), -1, -1):
            for a3 in range(min((S - 5*a5 - 4*a4)//3, n - a5 - a4), -1, -1):
                for a2 in range(min((S - 5*a5 - 4*a4 - 3*a3)//2, n - a5 - a4 - a3), -1, -1):
                    a1 = n - a5 - a4 - a3 - a2
                    if a1 >= 0 and 5*a5 + 4*a4 + 3*a3 + 2*a2 + a1 == S:
                        return (a1, a2, a3, a4, a5)
    # Should not happen
    return (0, 0, 0, 0, 0)

# ============================================================================
# HELPER FOR SEQUENTIAL MODULE
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
async def test_paper_solver(dut):
    """Test the paper_solver module."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases: (P_scaled, expected_tuple, description)
    test_cases = [
        (5000, (0,0,0,0,1), "P=5.0"),
        (4500, (0,0,0,1,1), "P=4.5"),
        (3200, (2,0,0,1,2), "P=3.20"),
        (1500, (1,1,0,0,0), "P=1.5"),
        (2500, (1,0,0,1,0), "P=2.5"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (P_scaled, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description} (P_scaled={P_scaled})")
        
        try:
            # Write P_scaled
            dut.P_scaled.value = P_scaled
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read outputs
            a1 = safe_int(dut.a1.value)
            a2 = safe_int(dut.a2.value)
            a3 = safe_int(dut.a3.value)
            a4 = safe_int(dut.a4.value)
            a5 = safe_int(dut.a5.value)
            
            result = (a1, a2, a3, a4, a5)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
