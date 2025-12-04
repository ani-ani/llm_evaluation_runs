import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_temp_predictor(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (n, temps[], expected)
    test_cases = [
        (5, [10,5,0,-5,-10,0,0,0], -15), # -10 + (-5) = -15
        (4, [1,1,1,1,0,0,0,0], 1),      # Arithmetic prog (difference 0)
        (3, [5,1,-5,0,0,0,0,0], -5),    # Not arithmetic
        (2, [900,1000,0,0,0,0,0,0], 1100), # 1000 + (1000-900)
        (8, [-1000,-995,-990,-985,-980,-975,-970,-965], -960) # -965 + 5
    ]

    passed = 0
    for idx, (n_val, temps, expected) in enumerate(test_cases):
        # Apply input
        dut.n.value = n_val
        for i in range(8):
            getattr(dut, f"temp_{i}").value = temps[i] if temps[i] >= -2048 and temps[i] <= 2047 else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 0
        while not dut.done.value and timeout < 15:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check result
        if timeout >= 15:
            dut._log.error(f"Test {idx} timed out")
        elif dut.prediction.value.signed_integer == expected:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: Predicted {dut.prediction.value.signed_integer}, expected {expected}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
