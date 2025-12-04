import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_shortest_cycle(dut):
    # Clock generation
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Test cases: (inputs, expected_output)
    test_cases = [
        ([3,6,28,9,0,0,0,0], 4),  # Original first case (trimmed to 4)
        ([5,12,9,16,48,0,0,0], 3), # Original second case (trimmed)
        ([1,2,4,8,0,0,0,0], 0)     # No cycle (-1)
    ]
    
    passed = 0
    for inputs, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Apply inputs
        for i in range(8):
            dut.__dict__[f'a{i}'].value = inputs[i] if i < len(inputs) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (50 cycles)
        for _ in range(50):
            await RisingEdge(dut.clk)
            
        # Check output
        if dut.done.value == 1:
            result = dut.cycle_len.value
            if result == expected:
                passed +=1
            else:
                dut._log.error(f'Test failed: Inputs={inputs[:4]} Result={result} Expected={expected}')
        else:
            dut._log.error('Done signal not asserted')
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
    
    dut._log.info(f'{passed}/{len(test_cases)} tests passed')