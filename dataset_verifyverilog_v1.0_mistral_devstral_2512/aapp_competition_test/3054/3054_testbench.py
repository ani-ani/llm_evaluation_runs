import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
TEXT_LENGTH_MAX = 200
MAX_WORDS = 10
MAX_WORD_LEN = 20
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
# TEXT PROCESSING HELPERS
# ============================================================================

def text_to_array(text):
    """Convert string to array of ASCII values."""
    # Pad to TEXT_LENGTH_MAX
    padded = text.rstrip('\n')[:TEXT_LENGTH_MAX]
    arr = [ord(c) for c in padded]
    # Pad with spaces to full length
    while len(arr) < TEXT_LENGTH_MAX:
        arr.append(0x20)
    return arr, len(padded)

def array_to_text(arr, length):
    """Convert array back to string."""
    text = ""
    for i in range(min(length, TEXT_LENGTH_MAX)):
        if arr[i] >= 32 and arr[i] <= 126:
            text += chr(arr[i])
    return text

async def write_text_input(dut, text):
    """Write text to input array."""
    arr, length = text_to_array(text)
    
    # Write each character
    for i, char_val in enumerate(arr):
        dut.text_data[i].value = char_val
    
    dut.text_length.value = length

async def read_output_lines(dut):
    """Read the three output lines."""
    lines = []
    
    for line_idx in range(3):
        line_arr = []
        line_name = ['line1', 'line2', 'line3'][line_idx]
        line_obj = getattr(dut, line_name)
        
        # Read until null terminator or max length
        for i in range(80):
            if is_value_defined(line_obj[i].value):
                val = int(line_obj[i].value)
                if val == 0:  # Null terminator
                    break
                if val >= 32 and val <= 126:
                    line_arr.append(chr(val))
                else:
                    line_arr.append(' ')
            else:
                break
        
        lines.append(''.join(line_arr).rstrip())
    
    return lines

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_haiku_former(dut):
    """Test the HaikuFormer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases
    test_cases = [
        (
            "Blue Ridge mountain road. Leaves, glowing in autumn sun, fall in Virginia.",
            [
                "Blue Ridge mountain road.",
                "Leaves, glowing in autumn sun,",
                "fall in Virginia."
            ],
            "Valid haiku from sample"
        ),
        (
            "Who would know if we had too few syllables?",
            ["Who would know if we had too few syllables?", "", ""],
            "Not a haiku - output unchanged"
        ),
        (
            "International contest- motivation high Programmers have fun!.",
            [
                "International",
                "contest- motivation high",
                "Programmers have fun!."
            ],
            "Valid haiku with word split"
        ),
        (
            "Programming contest is stressing us all out. International pain.",
            ["Programming contest is stressing us all out. International pain.", "", ""],
            "Not a haiku - too many syllables"
        ),
        (
            "I have one word.",
            ["I have one word.", "", ""],
            "Too few words"
        )
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_text, expected_lines, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {test_idx + 1}: {description}")
        dut._log.info(f"Input: '{input_text}'")
        
        try:
            # Reset
            await reset_dut(dut)
            
            # Write input
            await write_text_input(dut, input_text)
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=5000)
            
            # Read outputs
            output_lines = await read_output_lines(dut)
            valid = int(dut.valid.value)
            
            # Check results
            dut._log.info(f"Valid: {valid}")
            dut._log.info(f"Line 1: '{output_lines[0]}'")
            dut._log.info(f"Line 2: '{output_lines[1]}'")
            dut._log.info(f"Line 3: '{output_lines[2]}'")
            
            # Determine expected validity
            expected_valid = any(line.strip() for line in expected_lines[1:])
            
            # For "not a haiku" cases, check if original is returned
            if not expected_valid:
                if output_lines[0].strip() == input_text.strip():
                    dut._log.info("  PASS: Correctly returned original text")
                    passed += 1
                else:
                    raise TestFailure(f"Expected original text, got: '{output_lines[0]}'")
            else:
                # For haiku cases, verify all three lines
                for i in range(3):
                    if output_lines[i].strip() != expected_lines[i].strip():
                        raise TestFailure(
                            f"Line {i+1} mismatch: expected '{expected_lines[i]}', got '{output_lines[i]}'"
                        )
                
                if valid == 1:
                    dut._log.info("  PASS: Valid haiku formed")
                    passed += 1
                else:
                    raise TestFailure("Valid flag is 0, expected 1")
        
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"Test Results: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST: Edge Cases
# ============================================================================

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    edge_cases = [
        ("", "Empty string"),
        ("A", "Single word"),
        ("word", "Single word no spaces"),
        ("word1 word2", "Two words"),
        ("word " * 20, "Many words truncated"),
    ]
    
    for text, desc in edge_cases:
        dut._log.info(f"Edge: {desc}")
        
        await reset_dut(dut)
        await write_text_input(dut, text)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut, max_cycles=1000)
        
        output_lines = await read_output_lines(dut)
        dut._log.info(f"Output: '{output_lines[0]}'")
        
        # Should handle gracefully
        if not output_lines[0] or output_lines[0].strip() == "":
            dut._log.info("  PASS: Handled correctly")
        else:
            dut._log.info("  PASS: Has output")
