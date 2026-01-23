import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

def pack_values(values, element_bits=32, total_elements=16):
    """Pack list of values into a single integer, LSB first."""
    result = 0
    for i, val in enumerate(values):
        if i < total_elements:
            result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

def compute_expected(N, K, values):
    """Compute the expected sum of maximums modulo MOD."""
    MOD = 1000000007
    sorted_values = sorted(values[:N])
    total = 0
    for i in range(N):
        if i >= K-1:
            # Compute binomial coefficient C(i, K-1)
            import math
            comb = math.comb(i, K-1)
            total = (total + comb * sorted_values[i]) % MOD
    return total

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
async def test_sum_of_maxes(dut):
    """Main test function for sum_of_maxes module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (N, K, values, expected)
    test_cases = [
        (5, 3, [2, 4, 2, 3, 4], 39),
        (5, 1, [1, 0, 1, 1, 1], 4),
        (5, 2, [3, 3, 4, 0, 0], 31),
        (1, 1, [5], 5),
        (2, 1, [1, 2], 3),
        (2, 2, [1, 2], 2),
        (3, 2, [1, 2, 3], 8),
        (3, 3, [1, 2, 3], 3),
        (4, 2, [1, 2, 3, 4], 20),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, K, values, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, K={K}, values={values}")
        
        try:
            # Pack values into values_packed
            padded_values = values + [0] * (16 - len(values))
            packed = pack_values(padded_values, 32, 16)
            
            # Set inputs
            dut.N.value = N
            dut.K.value = K
            dut.values_packed.value = packed
            dut.start.value = 0
            dut.rst_n.value = 1
            
            # Wait for a few cycles
            await Timer(10, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")