import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
    arr = getattr(dut, array_name)
    for i, val in enumerate(values):
        arr[i].value = clamp_to_width(val, element_width)

async def read_array(dut, array_name, size):
    """Read array values."""
    results = []
    arr = getattr(dut, array_name)
    for i in range(size):
        if is_value_defined(arr[i].value):
            results.append(int(arr[i].value))
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
async def test_bitwise_xor(dut):
    """Test bitwise XOR operation on arrays."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array1, array2, expected_result)
    # Using 4-element test cases, padded to 8 elements
    test_cases = [
        (
            [10, 4, 6, 9, 0, 0, 0, 0],
            [5, 2, 3, 3, 0, 0, 0, 0],
            [15, 6, 5, 10, 0, 0, 0, 0],
            "Test 1: 10^5, 4^2, 6^3, 9^3"
        ),
        (
            [11, 5, 7, 10, 0, 0, 0, 0],
            [6, 3, 4, 4, 0, 0, 0, 0],
            [13, 6, 3, 14, 0, 0, 0, 0],
            "Test 2: 11^6, 5^3, 7^4, 10^4"
        ),
        (
            [12, 6, 8, 11, 0, 0, 0, 0],
            [7, 4, 5, 6, 0, 0, 0, 0],
            [11, 2, 13, 13, 0, 0, 0, 0],
            "Test 3: 12^7, 6^4, 8^5, 11^6"
        ),
        (
            [255, 128, 64, 32, 16, 8, 4, 2],
            [127, 64, 32, 16, 8, 4, 2, 1],
            [128, 192, 96, 48, 24, 12, 6, 3],
            "Test 4: Maximum values"
        ),
        (
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            "Test 5: All zeros"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr1, arr2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Write input arrays
            await write_array(dut, 'arr1', arr1, DATA_WIDTH)
            await write_array(dut, 'arr2', arr2, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result array
            result = await read_array(dut, 'result', ARRAY_SIZE)
            
            # Verify results
            for j in range(ARRAY_SIZE):
                if result[j] != expected[j]:
                    raise TestFailure(
                        f"Index {j}: expected {expected[j]}, got {result[j]}"
                    )
            
            cocotb.log.info(f"  PASS: Result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")