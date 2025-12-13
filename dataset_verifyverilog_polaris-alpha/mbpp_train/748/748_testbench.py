import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_space_inserter(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (input, expected_output, expected_length)
    test_cases = [
        ("Python",               "Python",                6),
        ("PyThon",               "Py Thon",               7),
        ("ABC",                  "A B C",                 5),
        ("GetReady",             "Get Ready",             9),
        ("PythonIsGreat",        "Python Is Great",      14)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected, exp_len in test_cases:
        # Pad input to 16 chars
        input_padded = list(input_str.ljust(16, '\\0'))
        input_ascii = [ord(c) for c in input_padded]
        
        # Pad expected to 32 chars
        expected_padded = list(expected.ljust(32, ' '))
        expected_ascii = [ord(c) for c in expected_padded]
        
        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        
        # Load input
        for i in range(16):
            dut.char_in[i].value = input_ascii[i]
        dut.length.value = len(input_str)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (+2 cycles margin)
        await ClockCycles(dut.clk, len(input_str) + 3)
        
        # Check done flag
        assert dut.done.value == 1, f"Done not set for input '{input_str}'"
        
        # Verify output
        success = True
        for i in range(32):
            actual = dut.char_out[i].value
            if actual != expected_ascii[i]:
                dut._log.error(f"Char {i}: Got '{chr(actual)}' ({actual}), expected '{chr(expected_ascii[i])}'")
                success = False
        
        # Check length
        if dut.out_length.value != exp_len:
            dut._log.error(f"Length error: Got {dut.out_length.value}, expected {exp_len}")
            success = False
        
        if success:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' → '{expected}'")
        else:
            dut._log.error(f"FAIL: '{input_str}' (expected '{expected}')")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total