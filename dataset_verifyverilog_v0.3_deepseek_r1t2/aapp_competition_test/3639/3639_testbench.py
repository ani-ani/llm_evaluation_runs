import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 24          # Q8.8 format (8 integer + 8 fractional + 8 guard bits)
RAIN_WIDTH = 8           # Rain per minute (0-255)
T = 16                   # Number of minutes
CLK_PERIOD_NS = 10       # Clock period
MAX_CYCLES = 1000        # Timeout for sequential operation

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
    if value < 0:
        # Handle signed values
        max_signed = (1 << (bits - 1)) - 1
        min_signed = -(1 << (bits - 1))
        value = max(min_signed, min(max_signed, value))
        return from_signed(value, bits)
    return min(max_val, max(0, value))

# ============================================================================
# FIXED-POINT CONVERSION
# ============================================================================

def float_to_q88(f):
    """Convert float to Q8.8 fixed-point format."""
    return int(f * 256)

def q88_to_float(q):
    """Convert Q8.8 fixed-point to float."""
    return q / 256.0

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_rain_array(dut, rain_values):
    """Write rain values to array, handling different interface styles."""
    # Ensure we don't exceed T elements
    rain_values = rain_values[:T]
    
    # Try 2D array first
    try:
        for i, val in enumerate(rain_values):
            dut.rain[i].value = clamp_to_width(val, RAIN_WIDTH)
        # Pad remaining with zeros
        for i in range(len(rain_values), T):
            dut.rain[i].value = 0
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (rain_0, rain_1, ...)
    for i, val in enumerate(rain_values):
        port_name = f"rain_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, RAIN_WIDTH)
        else:
            raise TestFailure(f"Cannot find rain port: {port_name}")
    
    # Pad remaining with zeros
    for i in range(len(rain_values), T):
        port_name = f"rain_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = 0

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
# REFERENCE IMPLEMENTATION (Python)
# ============================================================================

def compute_min_wetness(c_float, d_float, rain_values, T):
    """Reference implementation for test case generation."""
    # Convert to Q8.8
    c_fixed = float_to_q88(c_float)
    d_fixed = float_to_q88(d_float)
    
    # Precompute sweat for each travel duration
    sweat = [0] * (T + 1)
    for dt in range(1, T + 1):
        # sweat = c * (60*d)^2 / dt
        # In fixed-point: (c * (60*d)^2) / (dt * 256)
        # Use 64-bit intermediate to avoid overflow
        num = c_fixed * (60 * d_fixed) ** 2
        den = dt * 256
        sweat[dt] = num // den
    
    # Precompute cumulative rain sum
    cum_rain = [0] * (T + 1)
    for i in range(T):
        cum_rain[i+1] = cum_rain[i] + rain_values[i]
    
    # Find minimum wetness (departure at time 0)
    min_wetness = float('inf')
    for dt in range(1, T + 1):
        rain_sum = cum_rain[dt] - cum_rain[0]
        total = rain_sum + sweat[dt]
        if total < min_wetness:
            min_wetness = total
    
    return min_wetness

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rain_cycler(dut):
    """Main test function for rain_cycler module."""
    
    # Detect interface type
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases
    # Format: (c_float, d_float, rain_values, expected_description)
    test_cases = [
        # Example 1: All zeros, simple sweat calculation
        (0.1, 2.0, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "All zeros, c=0.1, d=2.0, T=5"),
        
        # Example 2: Some rain late in the trip
        (0.01, 2.0, [0, 0, 0, 100, 100, 100, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "Rain late, c=0.01, d=2.0"),
        
        # Edge case: Very high rain, early departure
        (0.1, 1.0, [100, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "High early rain, c=0.1, d=1.0"),
        
        # Edge case: Very low sweat constant
        (0.01, 5.0, [50, 50, 50, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "Low sweat, long distance, c=0.01, d=5.0"),
        
        # Edge case: High sweat constant
        (1.0, 2.0, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "High sweat, c=1.0, d=2.0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (c_float, d_float, rain_values, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        # Compute expected result using Python reference
        # Note: T is fixed at 16 in this test, but we only use first T_valid values
        # For these tests, we'll use T=5, 8, or 10 as appropriate
        T_valid = min(T, len(rain_values))
        expected_fixed = compute_min_wetness(c_float, d_float, rain_values[:T_valid], T_valid)
        expected_float = q88_to_float(expected_fixed)
        
        cocotb.log.info(f"  Expected (float): {expected_float:.4f}, Fixed: {expected_fixed}")
        
        try:
            # Convert inputs to fixed-point
            c_fixed = float_to_q88(c_float)
            d_fixed = float_to_q88(d_float)
            
            # Write inputs
            dut.c.value = clamp_to_width(c_fixed, DATA_WIDTH)
            dut.d.value = clamp_to_width(d_fixed, DATA_WIDTH)
            await write_rain_array(dut, rain_values)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result is undefined (X/Z)")
                
                result_raw = int(dut.result.value)
                result_float = q88_to_float(result_raw)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result is undefined (X/Z)")
                
                result_raw = int(dut.result.value)
                result_float = q88_to_float(result_raw)
            
            # Compare results (allow small tolerance for fixed-point rounding)
            diff = abs(result_float - expected_float)
            tolerance = 0.5  # Allow half a unit in Q8.8
            
            if diff > tolerance:
                raise TestFailure(f"Result mismatch: expected {expected_float:.4f}, got {result_float:.4f} (diff={diff:.4f})")
            
            cocotb.log.info(f"  Result: {result_float:.4f} (raw: {result_raw}) - PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST: Verify sweat calculation specifically
# ============================================================================

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_sweat_only(dut):
    """Test with zero rain to isolate sweat calculation."""
    
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case: c=0.1, d=2.0, all rain=0, T=5
    # Expected: sweat = 0.1 * (120)^2 / 5 = 288
    c_float = 0.1
    d_float = 2.0
    rain_values = [0] * 5
    
    c_fixed = float_to_q88(c_float)
    d_fixed = float_to_q88(d_float)
    
    dut.c.value = clamp_to_width(c_fixed, DATA_WIDTH)
    dut.d.value = clamp_to_width(d_fixed, DATA_WIDTH)
    await write_rain_array(dut, rain_values)
    
    if is_sequential:
        await start_computation(dut)
        await wait_for_done(dut)
        result_raw = int(dut.result.value)
    else:
        await Timer(100, units='ns')
        result_raw = int(dut.result.value)
    
    result_float = q88_to_float(result_raw)
    expected = 288.0
    
    if abs(result_float - expected) > 0.5:
        raise TestFailure(f"Sweat-only test failed: expected {expected}, got {result_float}")
    
    cocotb.log.info(f"Sweat-only test: {result_float} (expected {expected}) - PASS")
