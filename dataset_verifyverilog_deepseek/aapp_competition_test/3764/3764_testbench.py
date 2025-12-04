import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_jon_snow(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {'n':5, 'a':[9,7,11,15,5], 'k':1, 'x':2, 'max':13, 'min':7},
        {'n':2, 'a':[605,986], 'k':4, 'x':569, 'max':986, 'min':605},
        {'n':5, 'a':[1,2,3,4,5], 'k':3, 'x':64, 'max':69, 'min':3},
        {'n':1, 'a':[1], 'k':1, 'x':1, 'max':0, 'min':0}
    ]
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Load inputs (pad with 0 for n<8)
        a_padded = case['a'] + [0]*(8 - case['n'])
        dut.a0.value = a_padded[0]
        dut.a1.value = a_padded[1]
        dut.a2.value = a_padded[2]
        dut.a3.value = a_padded[3]
        dut.a4.value = a_padded[4]
        dut.a5.value = a_padded[5]
        dut.a6.value = a_padded[6]
        dut.a7.value = a_padded[7]
        dut.k.value = case['k']
        dut.x.value = case['x']
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (k+2 cycles)
        for _ in range(case['k'] + 2):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        if dut.done.value != 1:
            await RisingEdge(dut.done)
        
        if dut.max_strength.value == case['max'] and dut.min_strength.value == case['min']:
            passed += 1
        else:
            dut._log.error("Test failed: k=%d x=%d inputs=%s" 
                          + "
Got max=%d (exp %d), min=%d (exp %d)" % 
                          (case['k'], case['x'], str(case['a']), 
                           dut.max_strength.value, case['max'], 
                           dut.min_strength.value, case['min']))
    
    dut._log.info("%d/%d tests passed" % (passed, total))