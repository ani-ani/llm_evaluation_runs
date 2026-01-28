import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_STR_LEN = 16
CHAR_WIDTH = 8
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

async def write_string(dut, test_str):
    """Write string to input array, padding with zeros."""
    # Convert string to ASCII values
    ascii_values = [ord(c) for c in test_str]
    
    # Pad to MAX_STR_LEN with zeros
    while len(ascii_values) < MAX_STR_LEN:
        ascii_values.append(0)
    
    # Write each character individually
    for i in range(MAX_STR_LEN):
        dut.char_in[i].value = ascii_values[i]

async def read_string(dut):
    """Read output array and return as string (stopping at null)."""
    result = []
    for i in range(MAX_STR_LEN):
        if is_value_defined(dut.char_out[i].value):
            val = int(dut.char_out[i].value)
            if val != 0:  # Stop at null terminator
                result.append(chr(val))
            else:
                break
        else:
            break
    return ''.join(result)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_reverse_words(dut):
    """Test word reversal functionality."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        ("python program", "program python"),
        ("java language", "language java"),
        ("indian man", "man indian"),
        ("a b c", "c b a"),  # Additional edge case
        ("single", "single"),  # Single word
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input='\'{input_str}\'' Expected='\'{expected_str}\''")
        
        try:
            # Write input string
            await write_string(dut, input_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result_str = await read_string(dut)
            
            # Verify
            if result_str != expected_str:
                raise TestFailure(f"Expected '\'{expected_str}\'', got '\'{result_str}\''")
            
            cocotb.log.info(f"  PASS: result = '\'{result_str}\''")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
