import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 12
MAX_N = 8
K_MAX = 100
K_WIDTH = 8
RESULT_WIDTH = 5
CLK_PERIOD_NS = 10

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

async def write_array(dut, values):
    """Write values to arr[0] through arr[7]."""
    for i in range(MAX_N):
        if i < len(values):
            val = from_signed(values[i], DATA_WIDTH)
            dut.arr[i].value = val
        else:
            dut.arr[i].value = 0

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50000):
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
async def test_mirka_composition(dut):
    """Test Mirka's composition problem."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (N, array_values, expected_max_correct, expected_best_K)
    test_cases = [
        (5, [1, 2, 0, 3, 1], 3, 2),      # From problem statement
        (7, [2, 1, -6, -2, 1, 6, 10], 5, 4),  # From problem statement
        (3, [1, 1, 1], 3, 0),            # All equal
        (4, [0, 5, 0, 5], 4, 5),         # Alternating
        (2, [10, 5], 2, 5),              # Simple decreasing
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, values, expected_correct, expected_K) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: N={N}, values={values}")
        
        try:
            # Set N
            dut.N.value = N
            
            # Write array values
            await write_array(dut, values)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            max_correct = int(dut.max_correct.value)
            best_K = int(dut.best_K.value)
            
            cocotb.log.info(f"  Result: max_correct={max_correct}, best_K={best_K}")
            cocotb.log.info(f"  Expected: max_correct={expected_correct}, best_K={expected_K}")
            
            # Verify
            if max_correct != expected_correct:
                raise TestFailure(f"max_correct mismatch: expected {expected_correct}, got {max_correct}")
            
            if best_K != expected_K:
                raise TestFailure(f"best_K mismatch: expected {expected_K}, got {best_K}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
