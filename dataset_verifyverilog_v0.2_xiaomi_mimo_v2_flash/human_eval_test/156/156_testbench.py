import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_roman_converter(dut):
    """Test integer to Roman numeral conversion"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input, expected_string)
    test_cases = [
        (19, 'xix'),
        (152, 'clii'),
        (251, 'ccli'),
        (426, 'cdxxvi'),
        (500, 'd'),
        (1, 'i'),
        (4, 'iv'),
        (43, 'xliii'),
        (90, 'xc'),
        (94, 'xciv'),
        (532, 'dxxxii'),
        (900, 'cm'),
        (994, 'cmxciv'),
        (1000, 'm'),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for num, expected in test_cases:
        dut.number.value = num
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            print(f"Timeout for {num}")
            continue
        
        # Read output
        # Build string from byte array
        chars = []
        for i in range(10):
            char_val = int(dut.roman_chars[i].value)
            if char_val != 0:
                chars.append(chr(char_val))
        result = ''.join(chars)
        
        if result == expected:
            print(f"PASS: {num} -> {result} (expected {expected})")
            passed += 1
        else:
            print(f"FAIL: {num} -> {result} (expected {expected})")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total
