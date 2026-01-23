import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_count_char_position(dut):
    """Test count_char_position module with 3 test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_data.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (input_string_padded, expected_count, description)
        ("xbcefg" + "\x00"*2, 2, "xbcefg -> 2 matches: b(1), c(2)"),
        ("ABcED" + "\x00"*3, 3, "ABcED -> 3 matches: A(0), B(1), c(2)"),
        ("AbgdeF" + "\x00"*2, 5, "AbgdeF -> 5 matches: A(0), b(1), d(3), e(4), F(5)"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected, desc) in enumerate(test_cases):
        print(f"
Test {i+1}: {desc}")
        
        # Convert string to integer (little-endian)
        str_int = 0
        for j, ch in enumerate(input_str):
            str_int |= ord(ch) << (j * 8)
        
        dut.str_data.value = str_int
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (should be high after ~10 cycles)
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        actual = int(dut.count.value)
        print(f"  Expected: {expected}, Got: {actual}")
        
        assert dut.done.value == 1, "done signal not asserted"
        if actual == expected:
            print("  PASSED")
            passed += 1
        else:
            print("  FAILED")
            assert False, f"Mismatch: expected {expected}, got {actual}"
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed} of {total} tests passed"
