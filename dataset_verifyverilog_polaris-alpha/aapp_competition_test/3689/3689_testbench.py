import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_beautiful(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        {'n':3, 'k':2, 'digits':[3,5,3], 'expected':[3,5,3]},
        {'n':4, 'k':2, 'digits':[1,2,3,4], 'expected':[1,3,1,3]},
        {'n':2, 'k':1, 'digits':[3,1], 'expected':[3,3]},
        {'n':5, 'k':2, 'digits':[1,6,1,3,7], 'expected':[1,6,1,6,1]}
    ]
    
    passed = 0
    for tc in test_cases:
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = tc['n']
        dut.k.value = tc['k']
        for i in range(8):
            dut.digits[i].value = tc['digits'][i] if i < tc['n'] else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify outputs
        matches = True
        for i in range(tc['n']):
            if int(dut.y_digits[i].value) != tc['expected'][i]:
                matches = False
        
        if matches:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d k=%d input=%s received=%s expected=%s" % (
                tc['n'], tc['k'], tc['digits'],
                [int(dut.y_digits[i].value) for i in range(tc['n'])],
                tc['expected']))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))