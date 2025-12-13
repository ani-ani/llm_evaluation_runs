import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_array_sum(dut):
    # Define scaled test cases (n ≤8, arrays up to 15 elements)
    test_cases = [
        # Original examples
        {'n': 2, 'arr': [50, 50, 50, *[0]*12], 'exp': 150},
        {'n': 2, 'arr': [-1, -100, -1, *[0]*12], 'exp': 100},
        # Edge cases
        {'n': 5, 'arr': [-1,-2,-3,-4,-5,-6,-7,8,9,*[0]*6], 'exp': 45},
        {'n': 3, 'arr': [-100,100,100,100,100,*[0]*10], 'exp': 500},
        {'n': 4, 'arr': [-1,-1,-1,0,1,1,1,*[0]*8], 'exp': 5},
        # Zero-handling
        {'n': 5, 'arr': [0,0,0,0,0,-1,-1,-1,-1,*[0]*6], 'exp': 4}
    ]
    
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    passed = 0
    for tc in test_cases:
        # Reset and initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n_mode.value = tc['n']
        for i, val in enumerate(tc['arr']):
            dut.data[i].value = val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if int(dut.max_sum.value) != tc['exp']:
            dut._log.error(f"Test failed: n={tc['n']} arr={tc['arr']} Got {dut.max_sum.value}, expected {tc['exp']}")
        else:
            passed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
