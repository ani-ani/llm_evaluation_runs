import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 4
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'tuple_data'):
        dut.tuple_data.value = 0
    
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tuple_list_counter(dut):
    """Test tuple list counting functionality."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases:
    # Python tuple ([1, 2, 3, 4], [5, 6, 7, 8]) has 2 lists
    # Python tuple ([1, 2], [3, 4], [5, 6]) has 3 lists
    # Python tuple ([9, 8, 7, 6, 5, 4, 3, 2, 1]) has 1 list
    # 
    # In hardware: tuple_data = 8-bit vector where bit=1 means list
    # We represent each tuple element as 1 bit (list or not)
    # For these tests, we count the number of '1' bits in the input vector
    
    test_cases = [
        (0b00000011, 2, "Tuple with 2 lists"),
        (0b00000111, 3, "Tuple with 3 lists"),
        (0b00000001, 1, "Tuple with 1 list")
    ]
    
    passed = 0
    failed = 0
    
    for i, (tuple_input, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input tuple_data: 0b{tuple_input:08b} (expected result: {expected})")
        
        try:
            # Set tuple_data before starting
            if has_signal(dut, 'tuple_data'):
                dut.tuple_data.value = clamp_to_width(tuple_input, DATA_WIDTH)
            else:
                raise TestFailure("Signal 'tuple_data' not found in DUT")
            
            # Pulse start to begin computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read and verify result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
