import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

def float_to_q88(val):
    return int(val * 256) & 0xFFFF

@cocotb.test()
async def test_median(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {'data': [3,1,2,4,5], 'n':5, 'expected':3},
        {'data': [-10,4,6,1000,10,20]+[0,0], 'n':6, 'expected':8.0}, # Originally 15.0 but test expects 8.0
        {'data': [5], 'n':1, 'expected':5},
        {'data': [6,5]+[0]*6, 'n':2, 'expected':5.5},
        {'data': [8,1,3,9,9,2,7]+[0], 'n':7, 'expected':7}
    ]
    
    passed = 0
    for case in test_cases:
        # Apply test case
        for i in range(8):
            dut.data[i].value = float_to_q88(case['data'][i]) if i < case['n'] else 0
        dut.n.value = case['n']
        dut.start_trig.value = 1
        await RisingEdge(dut.clk)
        dut.start_trig.value = 0
        
        # Wait 8 cycles
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Check result
        expected_q88 = float_to_q88(case['expected'])
        actual = dut.result.value.signed_integer / 256.0
        
        if dut.result.value == expected_q88:
            passed += 1
            dut._log.info(f"PASS: {case['data'][:case['n']]} -> {case['expected']}")
        else:
            dut._log.error(f"FAIL: {case['data'][:case['n']]} -> {actual:.2f}, expected {case['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)