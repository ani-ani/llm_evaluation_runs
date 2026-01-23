import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def str_to_chars(s, width=8):
    """Convert string to list of ASCII values, pad with spaces."""
    chars = [ord(c) for c in s]
    while len(chars) < width:
        chars.append(0x20)  # Space pad
    return chars[:width]

def chars_to_str(chars):
    """Convert list of ASCII values to string, strip trailing spaces."""
    s = ''.join(chr(c) for c in chars)
    return s.rstrip(' ')

def anti_shuffle_sw(s, width=8):
    """Software implementation for verification."""
    chars = str_to_chars(s, width)
    result = chars[:]
    
    # Find words and sort them
    word_start = -1
    for i in range(width + 1):
        # Check if we're at end of a word
        if i == width or chars[i] == 0x20:
            if word_start >= 0:
                # Sort word from word_start to i-1
                word = chars[word_start:i]
                # Bubble sort
                for a in range(len(word)):
                    for b in range(len(word) - 1 - a):
                        if word[b] > word[b + 1]:
                            word[b], word[b + 1] = word[b + 1], word[b]
                # Put back
                for j, val in enumerate(word):
                    result[word_start + j] = val
                word_start = -1
        else:
            if word_start == -1:
                word_start = i
    
    return result

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_anti_shuffle(dut):
    """Test anti_shuffle module with various string inputs."""
    
    # Create and start clock (100 MHz)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_output_string)
    test_cases = [
        ('Hi', 'Hi'),
        ('hello', 'ehllo'),
        ('number', 'bemnru'),
        ('abcd', 'abcd'),
        ('Hello World!!!', 'Hello !!!Wdlor'),
        ('', ''),
        ('Hi. My name is Mister Robot. How are you?', '.Hi My aemn is Meirst .Rboot How aer ?ouy'),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: '{input_str}' -> '{expected_str}'")
        
        # Convert input to ASCII values
        input_chars = str_to_chars(input_str, 8)
        
        # Set input characters
        for j in range(8):
            # Check signal exists and width
            if hasattr(dut, f'char_{j}'):
                signal = getattr(dut, f'char_{j}')
                # Mask to 8 bits
                signal.value = input_chars[j] & 0xFF
            else:
                raise TestFailure(f"Missing signal: char_{j}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with cycle-based timeout
        max_cycles = 200
        done_seen = False
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            # Check if done is defined
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test {i+1}: done signal not asserted within {max_cycles} cycles")
        
        # Read result characters
        result_chars = []
        for j in range(8):
            if hasattr(dut, f'result_{j}'):
                signal = getattr(dut, f'result_{j}')
                if not is_value_defined(signal.value):
                    raise TestFailure(f"Test {i+1}: result_{j} is undefined")
                result_chars.append(int(signal.value) & 0xFF)
            else:
                raise TestFailure(f"Missing signal: result_{j}")
        
        # Convert result to string
        result_str = chars_to_str(result_chars)
        
        # Compare
        if result_str != expected_str:
            # Get detailed result for debugging
            result_full = ''.join(chr(c) for c in result_chars)
            raise TestFailure(
                f"Test {i+1} FAILED:\n"
                f"  Input:    '{input_str}'\n"
                f"  Expected: '{expected_str}'\n"
                f"  Got:      '{result_str}'\n"
                f"  Full:     '{result_full}'\n"
                f"  Raw:      {[hex(c) for c in result_chars]}"
            )
        
        dut._log.info(f"Test {i+1}: PASSED")
        passed += 1
        
        # Small gap between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed} of {total} tests passed")
