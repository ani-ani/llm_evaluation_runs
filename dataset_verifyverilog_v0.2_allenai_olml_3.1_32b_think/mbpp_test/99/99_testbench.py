import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_decimal_to_binary(dut):
    """Test decimal to binary conversion"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.decimal_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (8, '1000', 4),
        (18, '10010', 5),
        (7, '111', 3),
        (0, '0', 1),
        (65535, '1111111111111111', 16)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for decimal_val, expected_bin, expected_len in test_cases:
        # Start computation
        dut.decimal_in.value = decimal_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 30
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            print(f"Test failed: timeout for input {decimal_val}")
            continue
        
        # Read result
        result_str = dut.binary_str.value
        result_len = int(dut.length.value)
        
        # Convert binary string output to ASCII string
        # Extract bytes from the 80-bit output
        ascii_str = ""
        for i in range(10):
            byte_val = (result_str >> (72 - i*8)) & 0xFF
            if byte_val != 0:
                ascii_str += chr(byte_val)
        
        # Trim to actual length
        ascii_str = ascii_str[:result_len]
        
        # Check results
        if ascii_str == expected_bin and result_len == expected_len:
            passed += 1
            print(f"PASS: {decimal_val} -> {ascii_str} (len={result_len})")
        else:
            print(f"FAIL: {decimal_val} -> got '{ascii_str}' len={result_len}, expected '{expected_bin}' len={expected_len}")
            print(f"  Raw output: {result_str} (binary)")
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
