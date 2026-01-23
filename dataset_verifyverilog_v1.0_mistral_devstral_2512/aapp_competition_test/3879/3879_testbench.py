import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 32
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            # Try 2D array
            try:
                arr = getattr(dut, array_name)
                arr[i].value = clamp_to_width(val, element_width)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
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
            # Try 2D array
            try:
                arr = getattr(dut, array_name)
                if is_value_defined(arr[i].value):
                    results.append(int(arr[i].value))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
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
# CORE COMPUTATION (for verification)
# ============================================================================

def compute_core(num):
    """Remove all factors of 2 and 3 from a number."""
    while num % 2 == 0 and num != 0:
        num //= 2
    while num % 3 == 0 and num != 0:
        num //= 3
    return num

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_can_make_equal(dut):
    """Test if numbers can be made equal by multiplying by 2 and 3."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (numbers, expected_result, description)
    # Numbers are scaled to max 8 elements, using 32-bit values
    test_cases = [
        # Example 1: 75, 150, 75, 50 -> cores: 25, 25, 25, 25 -> Yes
        ([75, 150, 75, 50, 0, 0, 0, 0], 4, 1, "Example 1: 75 150 75 50"),
        # Example 2: 100, 150, 250 -> cores: 25, 25, 125 -> No
        ([100, 150, 250, 0, 0, 0, 0, 0], 3, 0, "Example 2: 100 150 250"),
        # Edge case: All ones -> Yes
        ([1, 1, 1, 1, 1, 1, 1, 1], 8, 1, "All ones"),
        # Edge case: Different cores -> No
        ([2, 3, 5, 0, 0, 0, 0, 0], 3, 0, "Different primes"),
        # Mixed with factors -> Yes
        ([48, 72, 24, 0, 0, 0, 0, 0], 3, 1, "48 72 24"),
        # Large numbers -> Yes
        ([1000000000, 2000000000, 500000000, 0, 0, 0, 0, 0], 3, 1, "Large numbers same core"),
        # Large numbers -> No
        ([1000000000, 1000000001, 0, 0, 0, 0, 0, 0], 2, 0, "Large numbers different cores"),
        # Single element -> Yes
        ([42, 0, 0, 0, 0, 0, 0, 0], 1, 1, "Single element"),
        # Two elements equal -> Yes
        ([12, 12, 0, 0, 0, 0, 0, 0], 2, 1, "Two equal"),
        # Two elements different -> No
        ([12, 18, 0, 0, 0, 0, 0, 0], 2, 0, "Two different"),
        # Powers of 2 -> Yes
        ([2, 4, 8, 16, 32, 64, 128, 256], 8, 1, "Powers of 2"),
        # Powers of 3 -> Yes
        ([3, 9, 27, 81, 0, 0, 0, 0], 4, 1, "Powers of 3"),
        # Mixed powers -> No
        ([4, 9, 0, 0, 0, 0, 0, 0], 2, 0, "Mixed powers"),
        # Zero handling -> No (zeros become 0, others become non-zero)
        ([0, 1, 0, 0, 0, 0, 0, 0], 3, 0, "Zero mixed"),
        # All zeros -> Yes (all cores are 0)
        ([0, 0, 0, 0, 0, 0, 0, 0], 8, 1, "All zeros"),
        # Real test case from examples
        ([34, 34, 68, 34, 34, 68, 34, 0], 7, 1, "7 elements from test"),
        # Real test case that should fail
        ([72, 96, 12, 18, 81, 20, 6, 2], 8, 0, "8 elements from test"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (numbers, length, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {description}")
        cocotb.log.info(f"  Input: {numbers[:length]}")
        cocotb.log.info(f"  Expected: {'Yes' if expected else 'No'}")
        
        try:
            # Write inputs
            await write_array(dut, 'arr', numbers, DATA_WIDTH)
            
            # Set length
            dut.len.value = length
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {'Yes' if expected else 'No'}, got {'Yes' if result else 'No'}")
            
            cocotb.log.info(f"  PASS: result = {'Yes' if result else 'No'}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Test Results: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
