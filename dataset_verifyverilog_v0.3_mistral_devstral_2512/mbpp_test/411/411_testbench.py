import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_LEN = 8
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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'input_valid'):
        dut.input_valid.value = 0
    
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

async def feed_string(dut, test_string):
    """Feed string characters to DUT one by one."""
    chars = list(test_string)
    
    for i, char in enumerate(chars):
        # Wait for rising edge
        await RisingEdge(dut.clk)
        
        # Set input signals
        dut.char_in.value = ord(char)
        dut.char_index.value = i
        dut.input_valid.value = 1
        
        # Wait for next edge to let DUT capture
        await RisingEdge(dut.clk)
        
        # Deassert valid
        dut.input_valid.value = 0
        
        # Wait a small amount for combinational logic
        await Timer(10, units='ns')
    
    # Send one more cycle with invalid data to signal end
    await RisingEdge(dut.clk)

async def read_output_string(dut):
    """Read output characters from DUT."""
    output_chars = []
    
    # Wait for output_valid to go high
    timeout = 0
    while not is_value_defined(dut.output_valid.value) or int(dut.output_valid.value) == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > MAX_CYCLES:
            break
    
    # Read all valid outputs
    max_output_len = MAX_LEN
    for i in range(max_output_len):
        if is_value_defined(dut.output_valid.value) and int(dut.output_valid.value) == 1:
            char_val = int(dut.char_out.value)
            if char_val != 0:  # Skip null bytes
                output_chars.append(chr(char_val))
        
        await RisingEdge(dut.clk)
    
    return ''.join(output_chars)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_snake_to_camel(dut):
    """Test snake_case to camelCase conversion."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ('android_tv', 'AndroidTv'),
        ('google_pixel', 'GooglePixel'),
        ('apple_watch', 'AppleWatch'),
        ('test_case', 'TestCase'),
        ('single', 'Single'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{input_str}' -> '{expected}'")
        
        try:
            # Feed input string
            await feed_string(dut, input_str)
            
            # Wait for computation
            await wait_for_done(dut)
            
            # Read output
            result = await read_output_string(dut)
            
            # Trim to expected length and compare
            result = result[:len(expected)]
            
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            cocotb.log.info(f"  PASS: '{result}'")
            passed += 1
            
            # Reset between tests
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")