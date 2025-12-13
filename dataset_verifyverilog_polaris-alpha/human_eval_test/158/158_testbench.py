import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_unique(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Helper function to pack strings
    def str_to_bin(s, max_len=8):
        s = s.ljust(max_len, '\\0')
        return int.from_bytes(s.encode('ascii'), 'big')
        
    # Adapted test cases (max 4 words, 8 chars each)
    test_cases = [
        ([str_to_bin("name"), str_to_bin("of"), str_to_bin("string"), 0], str_to_bin("string")),  # t1
        ([str_to_bin("name"), str_to_bin("enam"), str_to_bin("game"), 0], str_to_bin("enam")),   # t2
        ([str_to_bin("aaaaaaa"), str_to_bin("bb"), str_to_bin("cc"), 0], str_to_bin("aaaaaaa")), # t3
        ([str_to_bin("abc"), str_to_bin("cba"), 0, 0], str_to_bin("abc")),                      # t4
        ([str_to_bin("b"), 0, 0, 0], str_to_bin("b")),                                          # t9
    ]
    
    passed = 0
    total = len(test_cases)
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for inputs, expected in test_cases:
        # Load inputs
        for i in range(4):
            dut.word_array[i].value = inputs[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {hex(dut.result.value)} == {hex(expected)}")
        else:
            dut._log.error(f"FAIL: Got {hex(dut.result.value)}, expected {hex(expected)}")
        
        await RisingEdge(dut.clk)  # Extra cycle between tests
    
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")