import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_remainder_game(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Sample test cases
    test_cases = [
        (4, 5, [2,3,5,12,0,0,0,0], 1), # Yes
        (2, 7, [2,3,0,0,0,0,0,0], 0), # No
        (4, 16, [19,16,13,9,0,0,0,0], 1), # Yes
        (2, 8, [4,4,0,0,0,0,0,0], 0), # No
        (3, 4, [2,2,3,0,0,0,0,0], 1), # Yes
        (10, 4, [2,2,2,2,2,2,2,2], 1) # Yes
    ]
    
    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    
    passed = 0
    total = len(test_cases)
    
    for n_val, k_val, c_vals, expected in test_cases:
        # Load inputs
        dut.n.value = n_val
        dut.k.value = k_val
        for i in range(8):
            dut.c_i[i].value = c_vals[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 150 cycles)
        timeout = 150
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        assert timeout > 0, "Timeout waiting for done"
        
        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n_val}, k={k_val} => {dut.result.value}, expected {expected}")
        
        # Wait for done to go low
        while dut.done.value:
            await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"