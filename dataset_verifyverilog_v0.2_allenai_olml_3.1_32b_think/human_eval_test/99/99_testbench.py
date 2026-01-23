import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_closest_integer(dut):
    """Test the closest_integer module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_data.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert string to byte array
    def str_to_bytes(s):
        b = [0] * 8
        for i, c in enumerate(s):
            if i < 8:
                b[i] = ord(c)
        return b
    
    # Test cases: (input_string, expected_output)
    test_cases = [
        ("10", 10),
        ("14.5", 15),
        ("-15.5", -16),
        ("15.3", 15),
        ("0", 0),
        ("-0.5", -1),  # Edge case
        ("99.9", 100), # Round up
    ]
    
    passed = 0
    total = len(test_cases)
    
    for s_in, expected in test_cases:
        # Prepare input
        bytes_arr = str_to_bytes(s_in)
        dut.str_data.value = bytes_arr
        
        # Start pulse
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 30+2 cycles)
        timeout = 40
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for input {s_in}")
        
        # Check result
        # Result is 16-bit signed
        res = int(dut.result.value)
        if res >= 32768:
            res -= 65536
            
        if res == expected:
            passed += 1
            dut._log.info(f"PASS: {s_in} -> {res} (Expected {expected})")
        else:
            raise TestFailure(f"FAIL: {s_in} -> {res} (Expected {expected})")
            
    dut._log.info(f"Result: {passed}/{total} tests passed")
    assert passed == total
