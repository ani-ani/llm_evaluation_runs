import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

MOD = 1000000007

# Precomputed test cases for scaled inputs
test_cases = [
    (1, 1, 1, 17),
    (2, 1, 1, 100),  # Placeholder - actual value needs calculation
    (1, 2, 1, 75),   # Placeholder
    (3, 3, 3, 12345) # Placeholder
]

@cocotb.test()
async def test_card_game(dut):
    clock = Clock(dut.clk, 10, units="ns")  # Create a 10ns period clock
    cocotb.start_soon(clock.start())  # Start the clock

    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for (n, m, k, expected) in test_cases:
        # Apply inputs
        dut.N.value = n
        dut.M.value = m
        dut.K.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.result.value.integer
        if actual % MOD == expected % MOD:
            passed += 1
        else:
            dut._log.error(f"FAIL: N={n}, M={m}, K={k} -> Result={actual % MOD}, Expected={expected % MOD}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")