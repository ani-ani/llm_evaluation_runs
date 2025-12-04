import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_even_power_sum(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        {'n': 1, 'expected': 32},
        {'n': 2, 'expected': 1056},
        {'n': 3, 'expected': 8832},
        {'n': 4, 'expected': 8832 + (8**5)}
    ]
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input
        dut.n.value = case['n']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation (n cycles)
        cycles = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            cycles += 1
            
        # Verify result
        if int(dut.sum.value) == case['expected']:
            passed += 1
            dut._log.info(f"PASS: n={case['n']}, sum={dut.sum.value}")
        else:
            dut._log.error(f"FAIL: n={case['n']}, got {dut.sum.value}, expected {case['expected']}")
        
        await RisingEdge(dut.clk)
        
    dut._log.info(f"{passed}/{total} tests passed")