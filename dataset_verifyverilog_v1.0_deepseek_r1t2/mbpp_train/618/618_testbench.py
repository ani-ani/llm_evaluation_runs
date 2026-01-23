import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 16        # Input numerator/denominator width
RESULT_WIDTH = 32      # Output result width (Q16.16)
ARRAY_SIZE = 8         # Maximum array elements
CLK_PERIOD_NS = 10
MAX_CYCLES = 200       # Allow up to 8 elements + overhead

# Q16.16 conversion constants
FRAC_BITS = 16
SCALE_FACTOR = 1 << FRAC_BITS  # 65536

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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def float_to_fixed(f):
    """Convert float to Q16.16 fixed-point integer."""
    return int(f * SCALE_FACTOR)

def fixed_to_float(fixed):
    """Convert Q16.16 fixed-point integer to float."""
    return fixed / SCALE_FACTOR

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

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
async def test_div_list(dut):
    """Test element-wise division of two lists."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    else:
        # Combinational module - still need to wait for propagation
        cocotb.log.warning("Combinational module detected - using timer delays")
    
    # Define test cases: (numerators, denominators, expected_float_results, description)
    # Test 1: [4,5,6] / [1,2,3] = [4.0, 2.5, 2.0]
    # Test 2: [3,2] / [1,4] = [3.0, 0.5]
    # Test 3: [90,120] / [50,70] = [1.8, 1.7142857142857142]
    test_cases = [
        (
            [4, 5, 6],
            [1, 2, 3],
            [4.0, 2.5, 2.0],
            3,
            "Test 1: [4,5,6] / [1,2,3] = [4.0, 2.5, 2.0]"
        ),
        (
            [3, 2],
            [1, 4],
            [3.0, 0.5],
            2,
            "Test 2: [3,2] / [1,4] = [3.0, 0.5]"
        ),
        (
            [90, 120],
            [50, 70],
            [1.8, 1.7142857142857142],
            2,
            "Test 3: [90,120] / [50,70] = [1.8, 1.7142857142857142]"
        ),
        (
            [10, 20, 30, 40],
            [2, 4, 5, 8],
            [5.0, 5.0, 6.0, 5.0],
            4,
            "Test 4: [10,20,30,40] / [2,4,5,8] = [5.0, 5.0, 6.0, 5.0]"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (numerators, denominators, expected_floats, length, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {test_idx + 1}: {description}")
        cocotb.log.info(f"{'='*60}")
        
        try:
            # Convert float expectations to fixed-point
            expected_fixed = [float_to_fixed(f) for f in expected_floats]
            
            # Convert inputs to fixed-point
            numerator_fixed = [float_to_fixed(n) for n in numerators]
            denominator_fixed = [float_to_fixed(d) for d in denominators]
            
            # Pad arrays to full size if needed (for smaller test cases)
            numerator_padded = numerator_fixed + [0] * (ARRAY_SIZE - len(numerator_fixed))
            denominator_padded = denominator_fixed + [1] * (ARRAY_SIZE - len(denominator_fixed))  # Avoid div by 0
            
            cocotb.log.info(f"  Numerators (float): {numerators}")
            cocotb.log.info(f"  Denominators (float): {denominators}")
            cocotb.log.info(f"  Length: {length}")
            
            # Write inputs
            await write_array(dut, 'numerator', numerator_padded, DATA_WIDTH)
            await write_array(dut, 'denominator', denominator_padded, DATA_WIDTH)
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = length
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(1000, units='ns')
            
            # Read results
            results_raw = await read_array(dut, 'result', length)
            
            # Verify results
            for i in range(length):
                if results_raw[i] is None:
                    raise TestFailure(f"Result[{i}] is undefined (X/Z)")
                
                # Convert to float for comparison
                result_float = fixed_to_float(results_raw[i])
                expected_float = expected_floats[i]
                
                # Allow small floating-point tolerance (due to fixed-point rounding)
                tolerance = 0.0001
                if abs(result_float - expected_float) > tolerance:
                    raise TestFailure(
                        f"Result[{i}]: expected {expected_float} ({expected_fixed[i]:#x}), "
                        f"got {result_float} ({results_raw[i]:#x})"
                    )
                
                cocotb.log.info(f"  Result[{i}]: {result_float:.6f} (exact: {results_raw[i]:#010x}) [PASS]")
            
            cocotb.log.info(f"  ✓ Test {test_idx + 1} PASSED")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  ✗ Test {test_idx + 1} FAILED: {e}")
            failed += 1
        
        # Reset between tests for sequential modules
        if is_sequential and test_idx < len(test_cases) - 1:
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
