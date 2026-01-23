import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ROWS = 4
COLS = 2
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
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

TEST_CASES = [
    # Test 1
    (
        [[1, 3], [4, 5], [2, 9], [1, 10]],  # tuple1
        [[6, 7], [3, 9], [1, 1], [7, 3]],   # tuple2
        [[6, 7], [4, 9], [2, 9], [7, 10]],  # expected
        "Test 1: Basic maximization"
    ),
    # Test 2
    (
        [[2, 4], [5, 6], [3, 10], [2, 11]],
        [[7, 8], [4, 10], [2, 2], [8, 4]],
        [[7, 8], [5, 10], [3, 10], [8, 11]],
        "Test 2: Mixed values"
    ),
    # Test 3
    (
        [[3, 5], [6, 7], [4, 11], [3, 12]],
        [[8, 9], [5, 11], [3, 3], [9, 5]],
        [[8, 9], [6, 11], [4, 11], [9, 12]],
        "Test 3: Larger values"
    ),
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_tuple_elements(dut):
    """Test the max_tuple_elements module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for test_idx, (tuple1, tuple2, expected, description) in enumerate(TEST_CASES):
        cocotb.log.info(f"\nTest {test_idx + 1}: {description}")
        
        try:
            # Write inputs to individual ports
            # Row 0
            dut.arr_0_0.value = clamp_to_width(tuple1[0][0], DATA_WIDTH)
            dut.arr_0_1.value = clamp_to_width(tuple1[0][1], DATA_WIDTH)
            dut.brr_0_0.value = clamp_to_width(tuple2[0][0], DATA_WIDTH)
            dut.brr_0_1.value = clamp_to_width(tuple2[0][1], DATA_WIDTH)
            
            # Row 1
            dut.arr_1_0.value = clamp_to_width(tuple1[1][0], DATA_WIDTH)
            dut.arr_1_1.value = clamp_to_width(tuple1[1][1], DATA_WIDTH)
            dut.brr_1_0.value = clamp_to_width(tuple2[1][0], DATA_WIDTH)
            dut.brr_1_1.value = clamp_to_width(tuple2[1][1], DATA_WIDTH)
            
            # Row 2
            dut.arr_2_0.value = clamp_to_width(tuple1[2][0], DATA_WIDTH)
            dut.arr_2_1.value = clamp_to_width(tuple1[2][1], DATA_WIDTH)
            dut.brr_2_0.value = clamp_to_width(tuple2[2][0], DATA_WIDTH)
            dut.brr_2_1.value = clamp_to_width(tuple2[2][1], DATA_WIDTH)
            
            # Row 3
            dut.arr_3_0.value = clamp_to_width(tuple1[3][0], DATA_WIDTH)
            dut.arr_3_1.value = clamp_to_width(tuple1[3][1], DATA_WIDTH)
            dut.brr_3_0.value = clamp_to_width(tuple2[3][0], DATA_WIDTH)
            dut.brr_3_1.value = clamp_to_width(tuple2[3][1], DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read results
            results = [
                [int(dut.result_0_0.value), int(dut.result_0_1.value)],
                [int(dut.result_1_0.value), int(dut.result_1_1.value)],
                [int(dut.result_2_0.value), int(dut.result_2_1.value)],
                [int(dut.result_3_0.value), int(dut.result_3_1.value)],
            ]
            
            # Verify
            if results != expected:
                raise TestFailure(
                    f"Expected {expected}, got {results}"
                )
            
            cocotb.log.info(f"  PASS: {results}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")