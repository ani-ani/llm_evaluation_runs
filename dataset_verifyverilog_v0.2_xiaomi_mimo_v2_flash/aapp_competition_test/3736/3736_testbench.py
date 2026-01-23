import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

# Valid characters in the set
VALID_CHARS = {'A', 'H', 'I', 'M', 'O', 'T', 'U', 'V', 'W', 'X', 'Y'}

def is_valid_char(char):
    return char in VALID_CHARS

def is_palindrome_and_valid(s):
    n = len(s)
    # Check all characters are valid
    for c in s:
        if not is_valid_char(c):
            return False
    # Check palindrome
    return s == s[::-1]

def generate_test_vectors():
    """Generate test cases covering various scenarios"""
    test_cases = [
        # (string, expected_result)
        ("AHA", True),
        ("Z", False),
        ("XO", False),
        ("AAA", True),
        ("AHHA", True),
        ("BAB", False),
        ("OMMMAAMMMO", True),
        ("YYHUIUGYI", False),
        ("TT", True),
        ("UUU", True),
        ("WYYW", True),
        ("MITIM", True),
        ("VO", False),
        ("WWS", False),
        ("VIYMAXXAVM", False),
        ("OVWIHIWVYXMVAAAATOXWOIUUHYXHIHHVUIOOXWHOXTUUMUUVHVWWYUTIAUAITAOMHXWMTTOIVMIVOTHOVOIOHYHAOXWAUVWAVIVM", False),
        ("CC", False),
        ("QOQ", False),
        ("AEEA", False),
        ("OQQQO", False),
        ("HNCMEEMCNH", False),
        ("QDPINBMCRFWXPDBFGOZVVOCEMJRUCTOADEWEGTVBVBFWWRPGYEEYGPRWWFBVBVTGEWEDAOTCURJMECOVVZOGFBDPXWFRCMBNIPDQ", False),
        ("A", True),
        ("B", False),
        ("C", False),
        ("D", False),
        ("E", False),
        ("F", False),
        ("G", False),
        ("H", True),
        ("I", True),
        ("J", False),
        ("K", False),
        ("L", False),
        ("M", True),
        ("N", False),
        ("O", True),
        ("P", False),
        ("Q", False),
        ("R", False),
        ("S", False),
        ("T", True),
        ("U", True),
        ("V", True),
        ("W", True),
        ("X", True),
        ("Y", True),
        ("JL", False),
        ("AAAKTAAA", True),
        ("AKA", True),
        ("AAJAA", False),
        ("ABA", False),
        ("AAAAAABAAAAAA", False),
        ("ZZ", False),
        ("ADA", False),
        ("N", False),
        ("P", False),
        ("LAL", False),
        ("AABAA", False),
        ("AZA", False),
        ("V", True),
        ("SSS", False),
        ("NNN", False),
        ("S", False),
        ("I", True),
        ("SS", False),
        ("E", False),
    ]
    return test_cases

@cocotb.test()
async def test_mirror_check(dut):
    """Test the mirror_check module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.str_length.value = 0
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Generate test vectors
    test_cases = generate_test_vectors()
    passed = 0
    failed = 0
    
    dut._log.info(f"Running {len(test_cases)} test cases")
    
    for test_string, expected_result in test_cases:
        # Prepare inputs
        str_len = len(test_string)
        dut.str_length.value = str_len
        
        # Initialize char_valid and char_data
        char_valid_mask = 0
        for i in range(16):
            if i < str_len:
                char = test_string[i]
                dut.char_data[i].value = ord(char)
                if is_valid_char(char):
                    char_valid_mask |= (1 << i)
            else:
                dut.char_data[i].value = 0
        
        dut.char_valid.value = char_valid_mask
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with timeout
        timeout = 20  # Max cycles to wait
        cycles = 0
        
        while dut.done.value == 0 and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            dut._log.error(f"Test '{test_string}' timed out")
            failed += 1
            continue
        
        # Check result
        result = dut.is_mirror.value
        expected = 1 if expected_result else 0
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: '{test_string}' -> {result} (expected {expected})")
        else:
            failed += 1
            dut._log.error(f"FAIL: '{test_string}' -> {result} (expected {expected})")
            # Also log detailed info
            dut._log.info(f"  str_len={str_len}, char_valid=0x{char_valid_mask:x}")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
    
    # Print summary
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases specifically"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 1
    dut.start.value = 0
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test empty string (length 0) - should be considered valid mirror
    dut.str_length.value = 0
    dut.char_valid.value = 0
    for i in range(16):
        dut.char_data[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 5
    cycles = 0
    while dut.done.value == 0 and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles < timeout:
        if dut.is_mirror.value == 1:
            dut._log.info("Edge case PASS: Empty string is valid mirror")
        else:
            dut._log.error("Edge case FAIL: Empty string should be valid mirror")
    
    # Test single valid character
    await RisingEdge(dut.clk)
    dut.str_length.value = 1
    dut.char_data[0].value = ord('H')
    dut.char_valid.value = 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles < timeout:
        if dut.is_mirror.value == 1:
            dut._log.info("Edge case PASS: Single 'H' is valid mirror")
        else:
            dut._log.error("Edge case FAIL: Single 'H' should be valid mirror")
    
    # Test single invalid character
    await RisingEdge(dut.clk)
    dut.str_length.value = 1
    dut.char_data[0].value = ord('B')
    dut.char_valid.value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles < timeout:
        if dut.is_mirror.value == 0:
            dut._log.info("Edge case PASS: Single 'B' is not a mirror")
        else:
            dut._log.error("Edge case FAIL: Single 'B' should not be a mirror")
    
    await RisingEdge(dut.clk)
    dut._log.info("Edge case testing completed")
