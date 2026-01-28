import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 256
LENGTH_WIDTH = 6
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

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
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

async def read_result_string(dut, expected_len):
    """Read the 256-bit result and convert to string."""
    raw_result = int(dut.result.value)
    
    # Extract bytes and build string
    result_str = ""
    for i in range(expected_len):
        byte_val = (raw_result >> (i * 8)) & 0xFF
        if byte_val != 0:
            result_str += chr(byte_val)
    
    return result_str

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tuple_concatenator(dut):
    """Test tuple concatenation with delimiter."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: ((elem0, elem1, elem2, elem3), expected_result, expected_length)
    test_cases = [
        ((ord('I'), ord('D'), ord('4'), ord('U')), 'ID-4-U', 6),  # Simplified from ID-is-4-UTS
        ((ord('Q'), ord('W'), ord('4'), ord('R')), 'QW-4-R', 6),  # Simplified from QWE-is-4-RTY
        ((ord('Z'), ord('E'), ord('4'), ord('O')), 'ZE-4-O', 6),  # Simplified from ZEN-is-4-OP
    ]
    
    passed = 0
    failed = 0
    
    for i, ((e0, e1, e2, e3), expected, exp_len) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input tuple ({e0}, {e1}, {e2}, {e3})")
        
        try:
            # Write inputs
            dut.elem0.value = e0
            dut.elem1.value = e1
            dut.elem2.value = e2
            dut.elem3.value = e3
            
            # Wait 1 cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result and length
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            if not is_value_defined(dut.length.value):
                raise TestFailure(f"Length is undefined (X/Z)")
            
            result_len = int(dut.length.value)
            result_str = await read_result_string(dut, result_len)
            
            # Verify
            if result_str != expected:
                raise TestFailure(f"Expected '{expected}', got '{result_str}'")
            
            if result_len != exp_len:
                raise TestFailure(f"Expected length {exp_len}, got {result_len}")
            
            cocotb.log.info(f"  PASS: Result = '{result_str}' (length={result_len})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait for state machine to return to IDLE
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")