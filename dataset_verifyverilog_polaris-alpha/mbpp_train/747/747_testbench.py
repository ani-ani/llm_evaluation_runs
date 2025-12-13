import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_lcs(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Function to convert string to packed bytes
    def str_to_bytes(s):
        s = s.ljust(8, '\\0')  # Pad to 8 characters
        return [ord(c) for c in s[:8]]
    
    # Adapted test cases (original truncated to 8 chars)
    test_cases = [
        ("AGGT12", "12TXAYB", "12XBA",   2),  # Truncated to ("AGGT12", "12TXAY", "12XBA")
        ("Reels", "Reelsfor", "Reelsfor",  5),  # Truncated to first 8 chars
        ("abcd1e2", "bc12ea", "bd1ea",    3)   # Padded to 8 chars
    ]
    
    passed = 0
    total = len(test_cases)
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for idx, (s1, s2, s3, expected) in enumerate(test_cases):
        # Convert strings
        b1 = str_to_bytes(s1)
        b2 = str_to_bytes(s2)
        b3 = str_to_bytes(s3)
        
        # Load inputs
        dut.start.value = 0
        for i in range(8):
            dut.str1[i].value = b1[i]
            dut.str2[i].value = b2[i]
            dut.str3[i].value = b3[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (512 cycles + 2 for safety)
        wait_cycles = 514
        for _ in range(wait_cycles):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Check result
        result = dut.lcs_length.value
        if result == expected:
            passed += 1
            dut._log.info(f"TEST {idx} PASS
  Inputs: '{s1[:8]}', '{s2[:8]}', '{s3[:8]}'
  Result: {result}")
        else:
            dut._log.error(f"TEST {idx} FAIL
  Inputs: '{s1[:8]}', '{s2[:8]}', '{s3[:8]}'
  Expected: {expected}  Got: {result}")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TESTS SUMMARY: {passed}/{total} passed")