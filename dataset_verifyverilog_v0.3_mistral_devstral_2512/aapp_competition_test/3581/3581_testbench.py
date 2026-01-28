import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
H = 10  # Number of holes (N=4)
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

# Fixed-point conversion constants
FP_INT_BITS = 16
FP_FRAC_BITS = 16
FP_SCALE = 1 << FP_FRAC_BITS

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
    return min(max_val, max(0, value))

def float_to_fixed(f, frac_bits=FP_FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FP_FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

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
    
    # Try individual ports
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
# TEST CASES
# ============================================================================

# Sample test case from problem
TEST_CASE_1 = {
    "N": 4,
    "v": [40, 30, 30, 40, 20, 40, 50, 30, 30, 50],
    "p0": [0.0, 0.0, 0.3, 0.0, 0.2, 0.3, 0.0, 0.4, 0.4, 0.8],
    "p1": [0.0, 0.3, 0.0, 0.3, 0.2, 0.0, 0.8, 0.4, 0.4, 0.0],
    "p2": [0.45, 0.3, 0.3, 0.3, 0.2, 0.3, 0.0, 0.0, 0.0, 0.0],
    "p3": [0.45, 0.3, 0.3, 0.3, 0.2, 0.3, 0.0, 0.0, 0.0, 0.0],
    "p4": [0.1, 0.1, 0.1, 0.1, 0.2, 0.1, 0.2, 0.2, 0.2, 0.2],
    "expected": 32.6405451448
}

# Second test case
TEST_CASE_2 = {
    "N": 2,
    "v": [100, 50, 50],
    "p0": [0.0, 0.0, 0.90],
    "p1": [0.0, 0.90, 0.0],
    "p2": [0.45, 0.0, 0.0],
    "p3": [0.45, 0.0, 0.0],
    "p4": [0.1, 0.10, 0.10],
    "expected": 76.31578947368
}

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_arcade_expected(dut):
    """Test arcade expected value computation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test both test cases
    test_cases = [TEST_CASE_1]  # Only test first case for H=10
    
    passed = 0
    failed = 0
    
    for test_case in test_cases:
        cocotb.log.info(f"Testing N={test_case['N']}")
        
        try:
            # Convert inputs to fixed-point
            v_fp = [from_signed(int(v), 8) << 8 for v in test_case['v']]  # Q8.8 -> Q16.16
            p0_fp = [float_to_fixed(p) for p in test_case['p0']]
            p1_fp = [float_to_fixed(p) for p in test_case['p1']]
            p2_fp = [float_to_fixed(p) for p in test_case['p2']]
            p3_fp = [float_to_fixed(p) for p in test_case['p3']]
            p4_fp = [float_to_fixed(p) for p in test_case['p4']]
            
            # Write inputs
            await write_array(dut, 'v', v_fp, DATA_WIDTH)
            await write_array(dut, 'p0', p0_fp, DATA_WIDTH)
            await write_array(dut, 'p1', p1_fp, DATA_WIDTH)
            await write_array(dut, 'p2', p2_fp, DATA_WIDTH)
            await write_array(dut, 'p3', p3_fp, DATA_WIDTH)
            await write_array(dut, 'p4', p4_fp, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_raw = int(dut.result.value)
            result_signed = to_signed(result_raw, RESULT_WIDTH)
            result_float = fixed_to_float(result_signed)
            
            # Compare with expected
            expected = test_case['expected']
            error = abs(result_float - expected)
            rel_error = error / abs(expected) if expected != 0 else error
            
            if error < 1e-4 or rel_error < 1e-4:
                cocotb.log.info(f"  PASS: result = {result_float:.10f}, expected = {expected:.10f}")
                passed += 1
            else:
                raise TestFailure(f"Result {result_float:.10f} differs from expected {expected:.10f} by {error:.6f}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
