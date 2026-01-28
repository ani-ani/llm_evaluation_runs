import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert ASCII char to integer
def char_to_ascii(c):
    return ord(c)

# Helper to check if a character is a vowel
def is_vowel(char_code):
    vowels = [ord('a'), ord('e'), ord('i'), ord('o'), ord('u'),
              ord('A'), ord('E'), ord('I'), ord('O'), ord('U')]
    return char_code in vowels

# Helper to check if character is consonant (letter but not vowel)
def is_consonant(char_code):
    # Check if it's an English letter
    if (ord('a') <= char_code <= ord('z')) or (ord('A') <= char_code <= ord('Z')):
        return not is_vowel(char_code)
    return False

# Reference implementation for test generation
def reference_get_closest_vowel(word):
    """Reference Python implementation"""
    if len(word) < 3:
        return ""
    
    vowels = "aeiouAEIOU"
    
    # Scan from right to left, from position len-2 to 1
    for i in range(len(word) - 2, 0, -1):
        if word[i] in vowels:
            # Check if between two consonants
            left_is_consonant = False
            right_is_consonant = False
            
            # Check left side (i-1 and earlier)
            for j in range(i - 1, -1, -1):
                if word[j] in vowels:
                    break  # Hit vowel before consonant
                if is_consonant(ord(word[j])):
                    left_is_consonant = True
                    break
            
            # Check right side (i+1 and later)
            for j in range(i + 1, len(word)):
                if word[j] in vowels:
                    break  # Hit vowel before consonant
                if is_consonant(ord(word[j])):
                    right_is_consonant = True
                    break
            
            if left_is_consonant and right_is_consonant:
                return word[i]
    
    return ""

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_get_closest_vowel(dut):
    """Test get_closest_vowel module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    await cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.len.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("yogurt", "u"),
        ("full", "u"),
        ("easy", ""),
        ("eAsy", ""),
        ("ali", ""),
        ("bad", "a"),
        ("most", "o"),
        ("ab", ""),
        ("ba", ""),
        ("quick", ""),
        ("anime", "i"),
        ("Asia", ""),
        ("Above", "o"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (word, expected_vowel) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: word='{word}'")
        
        # Calculate expected result
        expected = char_to_ascii(expected_vowel) if expected_vowel else 0
        
        # Reset for new test
        dut.start.value = 0
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load characters into the module
        # First, wait for IDLE state
        await Timer(10, units="ns")
        
        # Load phase: send characters one by one
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Now load each character
        for j, char in enumerate(word):
            # Check if we're in LOAD state by polling
            # For simplicity, we'll just wait and send
            dut.char_in.value = ord(char)
            dut.len.value = len(word)
            await RisingEdge(dut.clk)
        
        # Wait for processing to complete (SCAN state)
        # Maximum 20 cycles for 16 characters
        done_found = False
        for cycle in range(25):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: done signal not asserted after 25 cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: word='{word}', expected {expected} (0x{expected:02X}), got {result} (0x{result:02X})")
        
        dut._log.info(f"Test {i+1}: PASSED - got 0x{result:02X}")
        passed += 1
        
        # Small delay between tests
        await Timer(100, units="ns")
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases for get_closest_vowel"""
    
    clock = Clock(dut.clk, 10, units="ns")
    await cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: very short words
    edge_cases = [
        ("a", 0),      # 1 char
        ("ab", 0),     # 2 chars, edge already tested
        ("abc", 0),    # 'a' and 'b' are edges, 'c' is consonant - no vowel between consonants
        ("bAc", 0),    # 'A' between 'b' and 'c' but 'A' is vowel, check if both sides consonant
    ]
    
    for word, expected in edge_cases:
        dut._log.info(f"Edge case: '{word}'")
        
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for char in word:
            dut.char_in.value = ord(char)
            dut.len.value = len(word)
            await RisingEdge(dut.clk)
        
        # Wait for completion
        for cycle in range(25):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Edge case '{word}': result undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Edge case '{word}': expected {expected}, got {result}")
        
        dut._log.info(f"Edge case '{word}': PASSED")
    
    dut._log.info("All edge cases passed")
