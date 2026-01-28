import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CHAR_WIDTH = 8
MAX_STRING_LEN = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_odd(dut):
    """Test remove_odd module - removes characters at odd positions."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_output)
    test_cases = [
        ("python", "yhn"),
        ("program", "rga"),
        ("language", "agae"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: remove_odd('{input_str}')")
        
        try:
            # Validate input length
            str_len = len(input_str)
            if str_len > MAX_STRING_LEN:
                cocotb.log.warning(f"Input too long, truncating to {MAX_STRING_LEN}")
                str_len = MAX_STRING_LEN
                input_str = input_str[:str_len]
            
            if str_len == 0:
                raise TestFailure("Input string cannot be empty")
            
            # Assert start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed characters sequentially and collect output
            output_chars = []
            
            for i in range(str_len):
                # Send current character
                dut.char_in.value = ord(input_str[i])
                await RisingEdge(dut.clk)
                
                # Check if output is valid (even position)
                if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                    if is_value_defined(dut.char_out.value):
                        char_val = int(dut.char_out.value)
                        output_chars.append(chr(char_val))
            
            # Wait for done signal
            await wait_for_done(dut)
            
            # Wait one more cycle to ensure DONE state completes
            await RisingEdge(dut.clk)
            
            # Form result string
            result = ''.join(output_chars)
            
            cocotb.log.info(f"  Input: '{input_str}' (len={str_len})")
            cocotb.log.info(f"  Expected: '{expected}'")
            cocotb.log.info(f"  Got: '{result}'")
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")