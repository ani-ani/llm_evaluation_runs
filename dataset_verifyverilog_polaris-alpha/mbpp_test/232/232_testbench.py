import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_top_n(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper function to pack data
    def pack_data(arr):
        val = 0
        for i in reversed(range(16)):
            val = (val << 8) | (arr[i] if i < len(arr) else 0)
        return val
    
    # Helper to unpack result
    def unpack_result(val, n):
        return [val >> (8*i) & 0xff for i in range(n)]
    
    test_cases = [
        {'input': [10,20,50,70,90,20,50,40,60,80,100], 'n': 2, 'expected': [100,90]},
        {'input': [10,20,50,70,90,20,50,40,60,80,100], 'n':5, 'expected': [100,90,80,70,60]},
        {'input': [10,20,50,70,90,20,50,40,60,80,100], 'n':3, 'expected': [100,90,80]},
        {'input': [127, -128], 'n':1, 'expected': [127]},
        {'input': [5,5,5,5], 'n':4, 'expected': [5,5,5,5]}
    ]
    
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for case in test_cases:
        # Extend input to 16 elements with zeros
        padded_input = case['input'] + [0]*(16 - len(case['input']))
        
        # Apply inputs
        dut.data.value = pack_data(padded_input)
        dut.n.value = case['n']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 16 cycles for processing
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Get result
        res = unpack_result(dut.result.value, case['n'])
        
        # Check
        if res == case['expected']:
            passed += 1
            dut._log.info(f"PASS: n={case['n']} input={case['input']} -> {res}")
        else:
            dut._log.error(f"FAIL: n={case['n']} input={case['input']}. Got {res}, expected {case['expected']}")
    
    total = len(test_cases)
    dut._log.info(f"Test summary: {passed}/{total} passed")
    assert passed == total