import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_palindrome(dut):
    # Test cases (input, expected output)
    test_cases = [
        (b'\x00\x00\x00\x00\x00\x00\x00\x00', b''),                    # Empty input
        (b'x\x00\x00\x00\x00\x00\x00\x00', b'x'),                      # Single char
        (b'xyz\x00\x00\x00\x00\x00', b'xyzyx'),                        # 'xyz' -> 'xyzyx'
        (b'xyx\x00\x00\x00\x00\x00', b'xyx'),                          # Already palindrome
        (b'jerry\x00\x00\x00', b'jerryrrej')                           # 'jerry' -> 'jerryrrej'
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.in_string.value = int.from_bytes(input_str, byteorder='little')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        result_bytes = dut.out_palindrome.value.to_bytes(16, byteorder='little')
        # Trim null bytes
        actual = result_bytes.split(b'\x00')[0]
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: '{input_str.decode().strip('\x00')}' -> '{expected.decode()}'")
        else:
            dut._log.error(f"FAIL: '{input_str.decode().strip('\x00')}' -> '{actual.decode()}', expected '{expected.decode()}'")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed
")
    assert passed == total