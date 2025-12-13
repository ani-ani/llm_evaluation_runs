import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_score(dut):
    # Test cases (original adapted for n<=8)
    test_cases = [
        {'n':5, 'arr':[3,1,5,2,6], 'expected':11},
        {'n':5, 'arr':[1,2,3,4,5], 'expected':6},
        {'n':5, 'arr':[1,100,101,100,1], 'expected':102},
        {'n':1, 'arr':[87], 'expected':0},
        {'n':3, 'arr':[31,19,5], 'expected':5},
        {'n':4, 'arr':[86,21,58,60], 'expected':118}
    ]
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = case['n']
        for i in range(8):
            if i < case['n']:
                dut.array_in[i].value = case['arr'][i]
            else:
                dut.array_in[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Verify result
        if int(dut.max_score.value) == case['expected']:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d arr=%s | Got %d, Expected %d" % (
                case['n'], str(case['arr']), int(dut.max_score.value), case['expected']))
        
        # Small delay between cases
        await Timer(20, units='ns')
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
