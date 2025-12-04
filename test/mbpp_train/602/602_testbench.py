import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_first_repeated(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        ("abcabc\0\0", "a", True),  # Test 1 (pad to 8 bytes)
        ("abc\0\0\0\0\0", None, False),  # Test 2
        ("123123\0\0", "1", True),  # Test 3
        ("11223344", "1", True),  # Additional edge case
        ("abcdefgh", None, False)  # No repeats
    ]
    
    passed = 0
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    for idx, (test_str, expected_char, expect_found) in enumerate(test_cases):
        # Convert string to byte array
        byte_arr = [ord(c) for c in test_str][:8]
        
        # Apply input
        for i in range(8):
            dut.str[i].value = byte_arr[i]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        actual_char = dut.result.value
        actual_found = dut.found.value
        
        if not expect_found:
            if actual_found != 0:
                dut._log.error(f"Test {idx+1} FAIL: Expected no repeat, found character {chr(actual_char)} ({actual_char})")
            else:
                passed += 1
                dut._log.info(f"Test {idx+1} PASS: No repeat (as expected)")
        else:
            expected_val = ord(expected_char)
            if (actual_char == expected_val) and (actual_found == 1):
                passed += 1
                dut._log.info(f"Test {idx+1} PASS: Found {expected_char} (as expected)")
            else:
                dut._log.error(f"Test {idx+1} FAIL: Expected {expected_char} ({expected_val}), got {chr(actual_char)} ({actual_char}})")
        
        # Wait 2 cycles before next test
        await ClockCycles(dut.clk, 2)
    
    dut._log.info(f"
TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
