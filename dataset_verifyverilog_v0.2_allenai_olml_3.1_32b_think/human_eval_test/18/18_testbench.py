import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_substring_counter(dut):
    """Test substring counter with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.main_string.value = 0
    dut.substring.value = 0
    dut.substring_length.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (main_string, substring, substring_length, expected_count, description)
        ("", "x", 1, 0, "empty string"),
        ("xyxyxyx", "x", 1, 4, "single char overlapping"),
        ("cacacacac", "cac", 3, 4, "3-char substring overlapping"),
        ("john doe", "john", 4, 1, "word match"),
        ("aaaa", "aa", 2, 3, "double char overlapping"),
        ("aaa", "a", 1, 3, "all single chars"),
        ("ababab", "ab", 2, 3, "ab pattern"),
        ("abcabc", "abc", 3, 2, "abc pattern"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for main_str, sub_str, sub_len, expected, desc in test_cases:
        # Prepare inputs
        main_bytes = main_str.encode('ascii') if main_str else b''
        sub_bytes = sub_str.encode('ascii') if sub_str else b''
        
        # Convert to 16×8-bit array for main_string
        main_array = [0] * 16
        for i, b in enumerate(main_bytes):
            if i < 16:
                main_array[i] = b
        
        # Convert to 8×8-bit array for substring
        sub_array = [0] * 8
        for i, b in enumerate(sub_bytes):
            if i < 8:
                sub_array[i] = b
        
        # Set inputs
        dut.main_string.value = 0
        for i in range(16):
            dut.main_string[i].value = main_array[i]
        
        dut.substring.value = 0
        for i in range(8):
            dut.substring[i].value = sub_array[i]
        
        dut.substring_length.value = sub_len
        dut.done.value = 0
        dut.count.value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 256 cycles)
        timeout = 300
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"Test '{desc}': TIMEOUT - did not complete")
            continue
        
        # Check result
        result = int(dut.count.value)
        if result == expected:
            print(f"Test '{desc}': PASS - got {result}")
            passed += 1
        else:
            print(f"Test '{desc}': FAIL - expected {expected}, got {result}")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
