import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from decimal import Decimal, getcontext

# Set high precision for expected values
getcontext().prec = 50

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling individual ports."""
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")

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

async def wait_for_done(dut, max_cycles=10000):
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
# FIXED-POINT CONVERSION
# ============================================================================

FRAC_BITS = 32

def float_to_q32(f):
    """Convert float to Q32.32 fixed-point integer."""
    return int(f * (1 << FRAC_BITS))

def q32_to_float(q):
    """Convert Q32.32 fixed-point integer to float."""
    return q / (1 << FRAC_BITS)

def compute_expected_fuel(n, m, a_list, b_list):
    """Compute expected fuel using high-precision arithmetic."""
    # Check for invalid coefficients
    if any(x <= 1 for x in a_list) or any(x <= 1 for x in b_list):
        return None
    
    total = Decimal(m)
    for x in a_list:
        total *= Decimal(x) / Decimal(x - 1)
    for x in b_list:
        total *= Decimal(x) / Decimal(x - 1)
    
    fuel = float(total - Decimal(m))
    return fuel

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fuel_calculator(dut):
    """Test fuel calculator with various cases."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    MAX_PLANETS = 8
    DATA_WIDTH = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, a_list, b_list, description)
    test_cases = [
        (2, 12, [11, 8], [7, 5], "Example 1: 2 planets"),
        (3, 1, [1, 4, 1], [2, 5, 3], "Example 2: impossible - a_i=1"),
        (6, 2, [4,6,3,3,5,6], [2,6,3,6,5,3], "Example 3: 6 planets"),
        (2, 1000, [12, 34], [56, 78], "Large fuel"),
        (2, 1, [2, 2], [2, 2], "Simple case"),
        (3, 3, [7,11,17], [19,31,33], "Another valid case"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, m, a_list, b_list, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {description}")
        
        # Compute expected result
        expected_fuel = compute_expected_fuel(n, m, a_list, b_list)
        
        # Prepare inputs
        # Pad lists to MAX_PLANETS with zeros
        a_padded = a_list + [0] * (MAX_PLANETS - len(a_list))
        b_padded = b_list + [0] * (MAX_PLANETS - len(b_list))
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        
        # Write arrays
        for i in range(MAX_PLANETS):
            setattr(dut, f'a_i_{i}', a_padded[i])
            setattr(dut, f'b_i_{i}', b_padded[i])
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=10000)
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read results
        impossible = int(dut.impossible.value)
        fuel_raw = int(dut.fuel.value)
        
        # Verify
        if expected_fuel is None:
            # Should be impossible
            if impossible:
                cocotb.log.info(f"  PASS: Correctly detected impossible case")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Expected impossible but got impossible={impossible}")
                failed += 1
        else:
            # Should be possible
            if impossible:
                cocotb.log.error(f"  FAIL: Expected possible but got impossible={impossible}")
                failed += 1
                continue
            
            # Convert output to float
            fuel_float = q32_to_float(fuel_raw)
            
            # Check with tolerance (relative error <= 1e-6)
            rel_error = abs(fuel_float - expected_fuel) / max(1, abs(expected_fuel))
            
            if rel_error <= 1e-6:
                cocotb.log.info(f"  PASS: fuel={fuel_float:.10f}, expected={expected_fuel:.10f}, rel_error={rel_error:.2e}")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: fuel={fuel_float:.10f}, expected={expected_fuel:.10f}, rel_error={rel_error:.2e}")
                failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
