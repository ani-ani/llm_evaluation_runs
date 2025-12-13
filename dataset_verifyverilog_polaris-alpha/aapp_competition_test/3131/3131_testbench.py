import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time
import math

MOD = 1000000007

@cocotb.test()
async def test_piano_sum(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Original: N=5, K=3, keys=[2,4,2,3,4] -> sum 39
        (5, 3, [2,4,2,3,4,0,0,0], 39),
        # Original: N=5, K=1, keys=[1,0,1,1,1] -> sum 4
        (5, 1, [1,0,1,1,1,0,0,0], 4),
        # Original: N=5, K=2, keys=[3,3,4,0,0] -> sum 31
        (5, 2, [3,3,4,0,0,0,0,0], 31),
        # Edge case: All zeros
        (3, 2, [0,0,0,0,0,0,0,0], 0),
        # Max value case
        (4, 3, [MOD-1,MOD-1,MOD-1,1,0,0,0,0], (4 * (MOD-1)) % MOD)
    ]
    
    passed = 0
    for n_val, k_val, keys, expected in test_cases:
        # Setup inputs
        dut.N.value = n_val
        dut.K.value = k_val
        for i in range(8):
            dut.keys[i].value = keys[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while (dut.done.value == 0):
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.result.value
        if int(actual) == expected % MOD:
            passed += 1
        else:
            dut._log.error(f"Test failed: N={n_val}, K={k_val}, Keys={keys[:n_val]}
"+
                          f"  Expected: {expected % MOD}, Got: {int(actual)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)