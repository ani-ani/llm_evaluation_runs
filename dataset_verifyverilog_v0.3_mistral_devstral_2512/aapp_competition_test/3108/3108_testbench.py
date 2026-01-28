import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8          # Bits per array element
ARRAY_SIZE = 8          # Number of array elements
K_WIDTH = 3             # Bits for K (1-8)
RESULT_WIDTH = 32       # Q16.16 fixed-point result
CLK_PERIOD_NS = 10      # Clock period in ns
MAX_CYCLES = 100        # Maximum cycles for computation
FRAC_BITS = 16          # Fractional bits for fixed-point

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
# FIXED-POINT CONVERSION
# ============================================================================

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

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

async def write_array(dut, values):
    """Write array values to individual ports arr_0..arr_7."""
    for i in range(ARRAY_SIZE):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {port_name} not found")

async def write_k(dut, k_val):
    """Write K value."""
    dut.K.value = clamp_to_width(k_val, K_WIDTH)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_average(dut):
    """Main test for MaxAverage module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Define test cases: (array_values, K, expected_average, description)
    # Array values are 8-element lists; pad with zeros if needed.
    test_cases = [
        # Example 1: 4 1 -> 1 2 3 4 -> max avg 4.0
        ([1, 2, 3, 4, 0, 0, 0, 0], 1, 4.000000, "Simple single element (max)"),
        # Example 2: 4 2 -> 2 4 3 4 -> max avg 3.666666
        ([2, 4, 3, 4, 0, 0, 0, 0], 2, 3.666666, "Length 3 subarray"),
        # Example 3: 6 3 -> 7 1 2 1 3 6 -> max avg 3.333333
        ([7, 1, 2, 1, 3, 6, 0, 0], 3, 3.333333, "Length 3 subarray"),
        # Additional test: K = N, all elements
        ([10, 20, 30, 40, 0, 0, 0, 0], 4, 25.000000, "Full array average"),
        # Additional test: K = 8, all elements
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, 4.500000, "All 8 elements"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, k_val, expected_avg, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        dut._log.info(f"  Array: {arr_vals[:8]}, K={k_val}")
        
        try:
            # Write inputs
            await write_array(dut, arr_vals)
            await write_k(dut, k_val)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fixed = int(dut.result.value)
            result_float = fixed_to_float(result_fixed)
            
            # Compare with tolerance
            tolerance = 0.001
            if abs(result_float - expected_avg) > tolerance:
                raise TestFailure(
                    f"Result mismatch: expected {expected_avg:.6f}, got {result_float:.6f} (diff {abs(result_float - expected_avg):.6f})"
                )
            
            dut._log.info(f"  Result: {result_float:.6f} (fixed: 0x{result_fixed:08X})")
            dut._log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait a few cycles between tests
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info("\n" + "="*60)
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST: RANDOMIZED
# ============================================================================

import random

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_randomized(dut):
    """Randomized test for robustness."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    random.seed(42)
    
    for test_num in range(5):
        # Generate random array (1-100) and K (1-8)
        arr_vals = [random.randint(1, 100) for _ in range(ARRAY_SIZE)]
        k_val = random.randint(1, ARRAY_SIZE)
        
        dut._log.info(f"\nRandom Test {test_num+1}: K={k_val}, Array={arr_vals}")
        
        # Compute expected using Python
        best_avg = 0.0
        for start in range(ARRAY_SIZE):
            for end in range(start + k_val - 1, ARRAY_SIZE):
                subarray = arr_vals[start:end+1]
                avg = sum(subarray) / len(subarray)
                if avg > best_avg:
                    best_avg = avg
        
        try:
            await write_array(dut, arr_vals)
            await write_k(dut, k_val)
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            result_fixed = int(dut.result.value)
            result_float = fixed_to_float(result_fixed)
            
            tolerance = 0.001
            if abs(result_float - best_avg) > tolerance:
                raise TestFailure(
                    f"Random test {test_num+1} failed: expected {best_avg:.6f}, got {result_float:.6f}"
                )
            
            dut._log.info(f"  Result: {result_float:.6f} [PASS]")
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            raise
        
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
    
    dut._log.info("\nAll randomized tests passed!")
