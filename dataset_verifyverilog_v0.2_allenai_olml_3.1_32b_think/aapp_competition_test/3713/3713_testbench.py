import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_hack_cows(dut):
    """Test the Cow Identification Hack module"""
    
    # Create a clock with a period of 10ns
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_len.value = 0
    dut.binary_string.value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run a test case
    async def run_test(string_val, length, expected):
        dut.binary_string.value = string_val
        dut.str_len.value = length
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 20 cycles)
        cycles = 0
        while not dut.done.value and cycles < 25:
            await RisingEdge(dut.clk)
            cycles += 1
            
        if cycles >= 25:
            raise TestFailure(f"Module did not finish for input {bin(string_val)}, length {length}")
            
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Input: {bin(string_val)}, Len: {length}. Expected {expected}, got {actual}")
        
        await RisingEdge(dut.clk)

    # Test Case 1: "10000011" (n=8)
    # Binary: 1,0,0,0,0,0,1,1 -> 0b11000001 reversed -> 0b10000011 is lsb-first 1,1,0,0,0,0,0,1
    # Wait, let's stick to the problem description: 10000011
    # Indices: 0:1, 1:0, 2:0, 3:0, 4:0, 5:0, 6:1, 7:1
    # LSB = index 0 = 1
    # 0x183 = 0001 1000 0011 (LSB first: 1,1,0,0,0,0,0,1) No, let's calculate carefully.
    # "10000011" -> bits: s[0]=1, s[1]=0, s[2]=0, s[3]=0, s[4]=0, s[5]=0, s[6]=1, s[7]=1
    # Value = 1*2^0 + 0*2^1 + 0*2^2 + 0*2^3 + 0*2^4 + 0*2^5 + 1*2^6 + 1*2^7
    # Value = 1 + 0 + 0 + 0 + 0 + 0 + 64 + 128 = 193 = 0xC1
    # Expected output: 5
    await run_test(193, 8, 5)
    
    # Test Case 2: "01" (n=2)
    # s[0]=0, s[1]=1 -> Value = 0*1 + 1*2 = 2
    # Expected output: 2
    await run_test(2, 2, 2)
    
    # Test Case 3: "10101" (n=5)
    # s[0]=1, s[1]=0, s[2]=1, s[3]=0, s[4]=1
    # Value = 1 + 0 + 4 + 0 + 16 = 21
    # Already alternating, length 5. No duplicates. Max LAS = 5. 
    # Wait, the problem says "min(res + 2, n)". If res=5, min(7, 5)=5.
    await run_test(21, 5, 5)
    
    # Test Case 4: "00000000000" (n=11) -> scaled down to max 16
    # Let's use a shorter version: "00000" (n=5)
    # s[0]=0, s[1]=0, s[2]=0, s[3]=0, s[4]=0
    # Value = 0
    # Transitions: 0. Base LAS = 1.
    # Duplicates: 4 pairs (00000). 
    # Result = 1 + min(2, 4) = 3.
    await run_test(0, 5, 3)
    
    # Test Case 5: "10101011" (n=8) - Broken alternating at end
    # s[0]=1, s[1]=0, s[2]=1, s[3]=0, s[4]=1, s[5]=0, s[6]=1, s[7]=1
    # Value = 1 + 0 + 4 + 0 + 16 + 0 + 64 + 128 = 213 = 0xD5
    # Transitions: 6 (1-0, 0-1, 1-0, 0-1, 1-0, 0-1). Wait, last is 1-1 (no transition).
    # Indices: 0-1 (T), 1-2 (T), 2-3 (T), 3-4 (T), 4-5 (T), 5-6 (T), 6-7 (F).
    # 6 transitions. Base LAS = 7.
    # Duplicates: 1 pair (6,7). 
    # Result = 7 + min(2, 1) = 8. 
    # But constraint is n=8, so min(8, 8) = 8.
    await run_test(213, 8, 8)
    
    dut._log.info("All tests passed!")