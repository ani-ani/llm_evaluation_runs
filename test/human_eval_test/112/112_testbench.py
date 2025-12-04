import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_string_filter(dut):
    # Clock generator
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Convert string to padded ASCII array
    def str_to_array(s, max_len=8):
        arr = [0]*max_len
        for i,c in enumerate(s[:max_len]):
            arr[i] = ord(c)
        return arr + [0]*(8-len(s))  # Ensure 8 elements

    # Test cases (original adapted to max 8 chars)
    test_cases = [
        ("abcde", "ae", 'bcd', False),
        ("abcdef", "b", 'acdef', False),
        ("abcdedcba"[:8], "ab", 'cdedc', True),
        ("dwik", "w", 'dik', False),
        ("a", "a", '', True),
        ("abcdedcba"[:8], "", 'abcdedcb', True),
        ("vabba", "v", 'abba', True),
        ("mamma", "mia", '', True)  # Note: filtered to empty string
    ]

    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for s_str, c_str, exp_str, exp_pal in test_cases:
        # Skip cases exceeding 8 chars (original had len=9)
        if len(s_str) > 8 or len(c_str) > 8:
            continue
        
        # Pad inputs to 8 chars
        s_arr = str_to_array(s_str, 8)
        c_arr = str_to_array(c_str, 8)
        
        # Apply inputs
        for i in range(8):
            dut.s_chars[i].value = s_arr[i]
            dut.c_chars[i].value = c_arr[i]
        dut.s_len.value = len(s_str)
        dut.c_len.value = len(c_str)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 9 cycles
        for _ in range(9):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        result_len = dut.result_len.value.integer
        pal_check = dut.is_palindrome.value
        result_str = ''.join([chr(dut.result_chars[i].value.integer) for i in range(result_len)])
        
        # Check
        if result_str == exp_str and pal_check == exp_pal:
            passed += 1
            dut._log.info(f"PASS: '{s_str}'-'{c_str}' -> '{result_str}' {pal_check}")
        else:
            dut._log.error(f"FAIL: '{s_str}'-'{c_str}'; Got '{result_str}' len={result_len} pal={pal_check}; Expected '{exp_str}' len={len(exp_str)} pal={exp_pal}")
        
        # Reset check between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)