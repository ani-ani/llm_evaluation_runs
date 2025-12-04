import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_string_sorter(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Helper function to convert string to byte array
    def str_to_bytes(s, length=64):
        s = s.ljust(length, ' ')
        return [ord(c) for c in s]

    # Test cases adapted for 64-byte input
    test_cases = [
        ('Hi', 'Hi'),
        ('hello', 'ehllo'),
        ('Hello World!!!', 'Hello    !!!Wdlor'),
        ('Hi. My name is Mister Robot. How are you?', '.Hi My aemn is Meirst .Rboot How aer ?ouy'),
        ('number', 'bemnru'),
        ('abcd', 'abcd'),
        ('', '')  # Empty string test
    ]

    passed = 0
    total_tests = len(test_cases)

    for input_str, expected in test_cases:
        # Convert test case to 64-byte format
        input_64 = input_str.ljust(64, ' ')
        expected_64 = expected.ljust(64, ' ')
        
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input
        for i, c in enumerate(input_64):
            dut.char_in[i].value = ord(c)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (with timeout)
        timeout = 700
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout <= 0:
            dut._log.error(f"Timeout for input '{input_str}'")
            continue
        
        # Verify output
        success = True
        for i in range(64):
            actual_char = chr(dut.char_out[i].value.integer)
            expected_char = expected_64[i]
            if actual_char != expected_char:
                dut._log.error(f"Position {i}: Expected '{expected_char}' (0x{ord(expected_char):02X}) "
                              f"got '{actual_char}' (0x{ord(actual_char):02X})")
                success = False
        
        if success:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' → '{expected}'")
        else:
            dut._log.error(f"FAIL: '{input_str}'")
    
    dut._log.info(f"SUMMARY: {passed}/{total_tests} tests passed")
    assert passed == total_tests