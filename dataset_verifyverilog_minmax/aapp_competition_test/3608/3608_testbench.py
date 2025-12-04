import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.utils import get_sim_time

MOD = 1000000007

async def reset(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.start.value = 0

@cocotb.test()
async def test_selector(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset(dut)
    
    test_cases = [
        # Input: N=3, a=[3,0,1], b=[0,1] (zero-padded for N=8)
        {"a": [3,0,1,0,0,0,0,0], "b": [0,1,0,0,0,0,0], "expected": 3 % MOD},
        # Input: N=4, a=[1,5,3,0], b=[0,2,1] (N=4 requires padding)
        {"a": [1,5,3,0,0,0,0,0], "b": [0,2,1,0,0,0,0], "expected": 33 % MOD},
        # Additional test case (N=2 to verify edge case)
        {"a": [2,3,0,0,0,0,0,0], "b": [4,0,0,0,0,0,0], "expected": (2*3 + 4) % MOD}
    ]
    passed = 0
    
    for case in test_cases:
        # Apply inputs
        for i in range(8):
            dut.a[i].value = case["a"][i] % MOD
            if i < 7:
                dut.b[i].value = case["b"][i] % MOD
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (10 cycles: reset + compute)
        for _ in range(12):
            await RisingEdge(dut.clk)
        
        # Verify output
        if dut.done.value == 1 and int(dut.result.value) == case["expected"]:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d, got %d" % (case["expected"], int(dut.result.value)))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))