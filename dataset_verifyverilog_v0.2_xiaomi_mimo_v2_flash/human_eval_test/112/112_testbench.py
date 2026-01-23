import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_reverse_delete(dut):
    """Test reverse_delete module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    for i in range(8):
        setattr(dut, f's_char_{i}').value = 0
        setattr(dut, f'c_char_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (s, c, expected_result, expected_palindrome)
        ("abcde", "ae", "bcd", False),
        ("abcdef", "b", "acdef", False),
        ("abcdedcba", "ab", "cdedc", True),
        ("dwik", "w", "dik", False),
        ("a", "a", "", True),
        ("abcdedcba", "", "abcdedcba", True),
        ("abcdedcba", "v", "abcdedcba", True),
        ("vabba", "v", "abba", True),
        ("mamma", "mia", "", True),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for s, c, expected_str, expected_palin in test_cases:
        # Setup inputs
        s_ascii = [ord(ch) for ch in s]
        c_ascii = [ord(ch) for ch in c]
        
        dut.s_len.value = len(s_ascii)
        dut.c_len.value = len(c_ascii)
        
        for i in range(8):
            if i < len(s_ascii):
                setattr(dut, f's_char_{i}').value = s_ascii[i]
            else:
                setattr(dut, f's_char_{i}').value = 0
            
            if i < len(c_ascii):
                setattr(dut, f'c_char_{i}').value = c_ascii[i]
            else:
                setattr(dut, f'c_char_{i}').value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Read results
        result_len = int(dut.result_len.value)
        result_str = ""
        for i in range(result_len):
            char_val = int(getattr(dut, f'result_char_{i}').value)
            result_str += chr(char_val)
        
        is_palin = bool(dut.is_palindrome.value)
        
        # Verify
        print(f"Test: s='{s}', c='{c}' -> result='{result_str}', palin={is_palin}")
        
        if result_str == expected_str and is_palin == expected_palin:
            passed += 1
            print("  PASS")
        else:
            print(f"  FAIL: Expected ('{expected_str}', {expected_palin})")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
