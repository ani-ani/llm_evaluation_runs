import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8              # Max energy bins
M = 2              # Max simulation energies
K_WIDTH = 8        # Photon count width
COST_WIDTH = 32    # Result width (Q16.16)
IDX_WIDTH = 3      # Index width (log2(N))
CLK_PERIOD_NS = 10

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
# ARRAY PACKING/UNPACKING HELPERS
# ============================================================================

def pack_array(values, element_bits):
    """Pack list of values into single integer, LSB first."""
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

def fixed_to_float(fixed, frac_bits=16):
    """Convert Q16.16 fixed-point to float."""
    return fixed / (1 << frac_bits)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_xray_sim(dut):
    """Test xray_sim module with scaled-down problem instances."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, k_list, expected_result_float)
    # Scaled versions of original test cases
    test_cases = [
        # Original: n=3, m=2, k=[3,1,1] -> 0.5
        # Scaled: Use n=3, m=2, k=[3,1,1] but with K_WIDTH=8
        (3, 2, [3, 1, 1, 0, 0, 0, 0, 0], 0.5),
        
        # Original: n=5, m=2, k=[8,0,5,13,2] -> 6.55
        # Scaled: Use n=5, m=2, k=[8,0,5,13,2] but with K_WIDTH=8
        (5, 2, [8, 0, 5, 13, 2, 0, 0, 0], 6.55),
        
        # Additional test: simple case with m=1
        (2, 1, [5, 5, 0, 0, 0, 0, 0, 0], 0.0),  # Both bins same weight, optimal E=1.5
        
        # Edge case: all photons in one bin
        (1, 1, [10, 0, 0, 0, 0, 0, 0, 0], 0.0),  # Optimal E=1
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, k_list, expected_float) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: n={n}, m={m}, k={k_list[:n]}")
        
        try:
            # Pack k values
            k_packed = pack_array(k_list, K_WIDTH)
            
            # Write inputs
            dut.n.value = n
            dut.m.value = m
            dut.k_packed.value = k_packed
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_raw = int(dut.result.value)
            result_float = fixed_to_float(result_raw)
            
            # Compare with tolerance (0.01 for fixed-point rounding)
            tolerance = 0.01
            if abs(result_float - expected_float) > tolerance:
                raise TestFailure(
                    f"Expected {expected_float:.4f}, got {result_float:.4f} "
                    f"(raw: {result_raw:#010x})"
                )
            
            cocotb.log.info(f"  PASS: result = {result_float:.4f} (raw: {result_raw:#010x})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
