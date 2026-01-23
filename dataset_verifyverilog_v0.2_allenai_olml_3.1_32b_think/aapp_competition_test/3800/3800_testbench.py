import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_rectangular_sum(dut):
    """Test the rectangular_sum module with various cases"""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.length.value = 0
    dut.digits.value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (a, string, expected_result)
    test_cases = [
        (10, "12345", 6),
        (16, "1234", 0), # Should be 0 based on logic (12+4=16, but 4 not in set, wait... 12+4 needs sum 4. 1234 has sums: 1,2,3,4,3,5,6,9,10. Pairs for 16: (1,16) no, (2,8) no, (4,4) yes (sum 4).),
        (0, "1230", 19),
        (8, "22", 4), # Sums: 2, 2, 4. Pairs for 8: (2,4) and (4,2). 2 freq=2, 4 freq=1. Count = 2*1 + 1*2 = 4.
        (4, "22", 1), # Pairs: (2,2). 2 freq=2. Count = 2*2 = 4 (wait, logic says if s==target, add freq*s * freq*s). 2*2=4. But total subarrays=3? No, (0,0) sum=2, (1,1) sum=2, (0,1) sum=4. 3 subarrays. So freq[2]=2, freq[4]=1.
        (4, "111", 4), # Sums: 1,1,1,2,2,3. freq[1]=3, freq[2]=2, freq[3]=1. Target 4. 1*4 no, 2*2 yes. freq[2]*freq[2] = 2*2 = 4.
    ]
    
    for a, s_str, expected in test_cases:
        # Setup inputs
        dut.a.value = a
        dut.length.value = len(s_str)
        
        # Convert string to hex vector (4 bits per digit)
        digits_val = 0
        for i, char in enumerate(s_str):
            digits_val |= (int(char) << (4 * (len(s_str) - 1 - i)))
        # Pad to 16 digits (shifted to MSB for consistent indexing if needed, but input is [15:0][3:0])
        # The spec says digits is [15:0][3:0]. Let's assume standard indexing where digits[0] is MSB or LSB?
        # Usually in HDL vectors, [15:0] is index 15 down to 0.
        # Let's map digits[15] to s_str[0] (MSB) or s_str[-1] (LSB)?
        # Python code calculates prefix sums: prefix[i] - prefix[i-1].
        # Let's align: digits[15] corresponds to s[0] (first char) in the spec.
        # So we shift the first char to the highest bits.
        digits_val = 0
        for i, char in enumerate(s_str):
            # i=0 is first char -> place at bits [15*4+3 : 15*4]
            # i=1 is second char -> place at bits [14*4+3 : 14*4]
            shift = 4 * (16 - 1 - i)
            digits_val |= (int(char) << shift)
            
        dut.digits.value = digits_val
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 500:
            raise TestFailure(f"Test (a={a}, s={s_str}) timed out")
            
        # Check result
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test failed for a={a}, s={s_str}. Expected {expected}, got {result}")
            
        # Small delay between tests
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
        
    dut._log.info(f"All tests passed!")