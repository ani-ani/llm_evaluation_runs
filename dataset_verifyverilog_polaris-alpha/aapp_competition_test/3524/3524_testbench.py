import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_interleave(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (adapted to 8 chars max)
    tests = [
        ("aabcad", 6, "aba", 3, "acd", 3, 1),
        ("aabcad", 6, "acb", 3, "aad", 3, 0),
        ("aabcad", 6, "acb", 3, "acd", 3, 0),
        ("abcdefgh", 8, "abcd", 4, "efgh", 4, 1),
        ("abracadabra", 8, "abc", 3, "radabra", 5, 0)  # Truncated to 8 chars
    ]
    
    passed = 0
    for s_str, len_s, s1_str, len_s1, s2_str, len_s2, expected in tests:
        # Wait for idle state
        await RisingEdge(dut.clk)
        while dut.done.value != 0:
            await RisingEdge(dut.clk)
        
        # Load inputs
        dut.start.value = 0
        dut.len_s.value = len_s
        for i in range(8):
            dut.s[i].value = ord(s_str[i]) - 97 if i < len_s else 0
        
        dut.len_s1.value = len_s1
        for i in range(8):
            dut.s1[i].value = ord(s1_str[i]) - 97 if i < len_s1 else 0
        
        dut.len_s2.value = len_s2
        for i in range(8):
            dut.s2[i].value = ord(s2_str[i]) - 97 if i < len_s2 else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: s=%s len=%d s1=%s len=%d s2=%s len=%d -> got %d expected %d" % 
                          (s_str, len_s, s1_str, len_s1, s2_str, len_s2, dut.result.value, expected))
        
        # Wait for done to deassert
        await RisingEdge(dut.clk)
    
    dut._log.info("%d/%d tests passed" % (passed, len(tests)))