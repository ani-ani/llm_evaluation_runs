import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_bulbasaur_counter(dut):
    # Test cases (input_string, expected_output)
    test_cases = [
        ("Bulbbasaur", 1),
        ("F", 0),
        ("aBddulbasaurrgndgbualdBdsagaurrgndbb", 2),  # Trimmed to 64 chars
        ("BBBuuulllbbbaaasssaaauuurrr", 3),
        ("BBuullbbaassaarr", 0)
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    total = len(test_cases)
    
    for data, expected in test_cases:
        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.valid_char.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply input string (truncated to 64 chars)
        s = data[:64]
        dut.str_len.value = len(s)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters one per clock
        for c in s:
            dut.char_in.value = ord(c)
            dut.valid_char.value = 1
            await RisingEdge(dut.clk)
        dut.valid_char.value = 0
        
        # Wait for result (67 cycles)
        for _ in range(70):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        result = dut.bulbasaur_count.value
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"FAIL: Input '{data} ({s})' got {result}, expected {expected}")
    
    dut._log.info(f"TESTS COMPLETE: {passed}/{total} passed")