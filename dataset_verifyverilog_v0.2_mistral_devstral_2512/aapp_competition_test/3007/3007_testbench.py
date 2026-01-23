import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_bling_calculator(dut):
    """Test the Max Bling Calculator with various scenarios"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (d, b, f, t0, t1, t2, expected)
    test_cases = [
        (4, 0, 1, 0, 0, 0, 300),   # Case 1: Plant 1, day 3 yield 3, sell 4 on day 4 -> 400? Wait, 3 fruits yield day 3. Day 4 has 3. Sell 300. Python says 300.
        (5, 0, 1, 0, 1, 0, 1900),  # Case 2: Exotic profit focus
        (6, 0, 1, 1, 0, 0, 2300),  # Case 3
        (10, 399, 0, 0, 0, 0, 399),# Case 4: No money for exotic, 0 fruits
        (1, 400, 0, 0, 0, 0, 500), # Case 5: 1 day left, buy exotic and sell
    ]

    for i, (d, b, f, t0, t1, t2, expected) in enumerate(test_cases):
        # Load inputs
        dut.d_in.value = d
        dut.b_in.value = b
        dut.f_in.value = f
        dut.t0_in.value = t0
        dut.t1_in.value = t1
        dut.t2_in.value = t2
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
            # Safety timeout (max 40 cycles + overhead)
            if int(dut.sim_time.value) > 1000:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Test {i+1} failed: Input ({d},{b},{f},{t0},{t1},{t2}) Expected {expected}, got {actual}")
        else:
            print(f"Test {i+1} passed: {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    print(f"All {len(test_cases)} tests passed!")
