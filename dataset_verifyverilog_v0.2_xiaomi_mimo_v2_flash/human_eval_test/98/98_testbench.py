import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_count_upper(dut):
    """Test count_upper module with various strings"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_len.value = 0
    dut.str_data.value = 0
    await Timer(25, units="ns")
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert string to 128-bit packed format
    def pack_string(s):
        data = 0
        for i, char in enumerate(s):
            data |= ord(char) << (8 * i)
        return data
    
    # Helper function to run a test
    async def run_test(test_str, expected):
        dut._log.info(f"Testing: '{test_str}' expecting {expected}")
        dut.str_len.value = len(test_str)
        dut.str_data.value = pack_string(test_str)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (8 cycles for 8 even positions)
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        done_bit = int(dut.done.value)
        assert actual == expected, f"Expected {expected}, got {actual}"
        assert done_bit == 1, "Done signal should be high"
        
        # Wait one more cycle to return to IDLE
        await RisingEdge(dut.clk)
    
    # Test cases
    await run_test('aBCdEf', 1)   # aBCdEf: indices 0,2,4: 'a'(vowel,lower), 'C'(not vowel), 'E'(vowel,upper) -> 1
    await run_test('abcdefg', 0)  # all lowercase
    await run_test('dBBE', 0)     # dBBE: indices 0,2: 'd', 'B' -> 0
    await run_test('B', 0)        # B at index 0 (even) but not vowel -> 0
    await run_test('U', 1)        # U at index 0 (even) and vowel -> 1
    await run_test('', 0)         # empty string
    await run_test('EEEE', 2)     # EEEE: indices 0,2: 'E','E' -> 2
    
    dut._log.info("All tests passed! 7/7")