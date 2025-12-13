import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_meow(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper to pack string into 40-bit input (each char 5 bits: a=0, z=25)
    def pack_str(s):
        val = 0
        for c in s.ljust(8)[:8]:
            val = (val << 5) | (ord(c) - ord('a'))
        return val
    
    test_cases = [
        ("meow", 0),   # Perfect match
        ("mewo", 1),   # 1 swap needed
        ("meo", 1),    # 1 insert
        ("meowmeow", 0), # Multiple matches
        ("cat", 4),     # Full replace
        ("xmeowxxx", 0), # Substring match
        ("xmeoxwxx", 1)  # 1 replace needed
    ]
    
    passed = 0
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for s, expected in test_cases:
        dut.str_in.value = pack_str(s)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 20
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error("Test timed out for input: " + s)
            continue
        
        if dut.min_ops.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: {s} => {dut.min_ops.value}, expected {expected}")
        
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)