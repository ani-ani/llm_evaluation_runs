import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def stone_game_test(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset system
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Inputs: (n, [8 stones]), expected
        # Original tests
        (1, [0] + [0]*7, 0),   # cslnb
        (2, [1,0] + [0]*6, 0), # cslnb
        (2, [2,2] + [0]*6, 1), # sjfnb
        (3, [2,3,1] + [0]*5, 1), # sjfnb
        
        # Modified tests for hardware limits
        (3, [0,0,5] + [0]*5, 0),  # cslnb (duplicates)
        (5, [0,5,6,7,9] + [0]*3, 1), # sjfnb (valid parity)
        (5, [0,5,5,6,6] + [0]*3, 0)  # cslnb (multiple dupes)
    ]
    
    passed = 0
    for test_id, (n_val, stones, expected) in enumerate(test_cases):
        # Set inputs
        dut.start.value = 0
        dut.n.value = n_val
        for i in range(8):
            dut.stones[i].value = stones[i]
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.outcome.value
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Case {test_id}: {stones[:n_val]} => {actual}, expected {expected}")
        
        # Wait 1 cycle after done
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)