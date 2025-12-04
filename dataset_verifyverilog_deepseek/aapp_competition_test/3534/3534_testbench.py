import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_mirka_solver(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {'N':5, 'a':[1,2,0,3,1], 'exp_correct':3, 'exp_K':2},
        {'N':7, 'a':[2,1,-6,-2,1,6,10], 'exp_correct':5, 'exp_K':4},
        {'N':4, 'a':[5,5,5,5], 'exp_correct':4, 'exp_K':0}
    ]
    
    passed = 0
    for test in test_cases:
        # Apply inputs
        for i in range(8):
            if i < len(test['a']):
                getattr(dut, f'a{i}').value = test['a'][i]
            else:
                getattr(dut, f'a{i}').value = 0
        dut.N.value = test['N']
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check outputs
        if dut.max_correct.value == test['exp_correct'] and dut.best_K.value == test['exp_K']:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {test['exp_correct']} correct with K={test['exp_K']} got {dut.max_correct.value} with K={dut.best_K.value}")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")