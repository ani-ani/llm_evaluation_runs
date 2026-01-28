import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

async def write_array(dut, values):
    """Write values to arr_0 .. arr_7."""
    for i in range(ARRAY_SIZE):
        # Clamp to 32-bit signed
        val = clamp_to_width(values[i] & 0xFFFFFFFF, 32)
        # Convert negative numbers to unsigned representation
        if values[i] < 0:
            val = from_signed(values[i], 32)
        else:
            val = values[i]
        setattr(dut, f'arr_{i}').value = val

async def read_result(dut):
    """Read result_sum and result_count, convert to Python int."""
    result_sum = 0
    result_count = 0
    if is_value_defined(dut.result_sum.value):
        result_sum = int(dut.result_sum.value)
        # Sign-extend result_sum if needed (but it should be non-negative)
    if is_value_defined(dut.result_count.value):
        result_count = int(dut.result_count.value)
    return result_sum, result_count

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
# COMPUTATION OF EXPECTED RESULT
# ============================================================================

def compute_max_average(values):
    """Compute the maximum average for a given list of values (size <= 8)."""
    N = len(values)
    # Prefix sums: pref[0] = 0, pref[i] = sum of first i values
    pref = [0]*(N+1)
    for i in range(1, N+1):
        pref[i] = pref[i-1] + values[i-1]
    # Suffix sums: suff[N] = values[N-1], suff[j] = sum from j to N
    suff = [0]*(N+2)
    for j in range(N, 0, -1):
        suff[j] = suff[j+1] + values[j-1]
    best_sum = 0
    best_count = 1  # represent average 0
    best_avg = 0.0
    # Iterate over all (i, j) pairs
    for i in range(0, N+1):
        for j in range(i+1, N+2):
            total_sum = pref[i] + suff[j]
            total_count = i + (N - j + 1)
            if total_count > 0:
                avg = total_sum / total_count
                if avg > best_avg:
                    best_avg = avg
                    best_sum = total_sum
                    best_count = total_count
    return best_sum, best_count, best_avg

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_stop_counting(dut):
    """Test the stop_counting module."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (description, list of 8 values, expected average)
    # We pad the sample inputs with -1e9 (very negative) to avoid affecting the result
    # For N<8, the remaining values are set to -1e9 (which will never be counted)
    INF_NEG = -1000000000
    test_cases = [
        (
            "Sample 1: 5 cards [10,10,-10,-4,10] padded",
            [10, 10, -10, -4, 10, INF_NEG, INF_NEG, INF_NEG],
            10.0
        ),
        (
            "Sample 2: 4 negative cards [-3,-1,-4,-1] padded",
            [-3, -1, -4, -1, INF_NEG, INF_NEG, INF_NEG, INF_NEG],
            0.0
        ),
        (
            "Sample 3: 5 mixed [5,7,-10,-4,3] padded",
            [5, 7, -10, -4, 3, INF_NEG, INF_NEG, INF_NEG],
            6.0
        ),
        (
            "All zeros",
            [0,0,0,0,0,0,0,0],
            0.0
        ),
    ]
    
    passed = 0
    failed = 0
    
    for desc, values, expected_avg in test_cases:
        cocotb.log.info(f"Test: {desc}")
        cocotb.log.info(f"  Input array: {values}")
        cocotb.log.info(f"  Expected average: {expected_avg}")
        
        try:
            # Write inputs
            await write_array(dut, values)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result_sum, result_count = await read_result(dut)
            
            # Compute actual average
            if result_count == 0:
                actual_avg = 0.0
            else:
                actual_avg = result_sum / result_count
            
            cocotb.log.info(f"  Result: sum={result_sum}, count={result_count}, average={actual_avg}")
            
            # Compare with tolerance
            if abs(actual_avg - expected_avg) > 1e-6:
                raise TestFailure(f"Average mismatch: expected {expected_avg}, got {actual_avg}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
