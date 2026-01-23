import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_weather_prediction(dut):
    """Test the weather prediction module with various arithmetic progression scenarios"""
    
    # Create a clock with a period of 10ns
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.temp_in.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run a test case
    async def run_test_case(n_val, temps, expected):
        dut._log.info(f"Running test case: n={n_val}, temps={temps}, expected={expected}")
        
        # Load n value
        dut.n.value = n_val
        
        # Start the process
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed temperatures sequentially
        for t in temps:
            dut.temp_in.value = t
            await RisingEdge(dut.clk)
            # Wait for state transition if needed
            
        # Wait for computation to complete (DONE state)
        # We need to wait until done is asserted
        # The module logic takes a few cycles after inputs
        max_cycles = 20
        found_done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if dut.done.value == 1 and dut.valid.value == 1:
                found_done = True
                break
        
        if not found_done:
            raise TestFailure(f"Module did not assert done within {max_cycles} cycles")
            
        # Check prediction
        actual = int(dut.prediction.value)
        if actual != expected:
            raise TestFailure(f"Prediction mismatch: expected {expected}, got {actual}")
        
        dut._log.info(f"Result: {actual} (Match: OK)")
        
        # Reset for next test (optional but good practice to return to IDLE)
        dut.start.value = 0
        await RisingEdge(dut.clk)

    # Test Case 1: Example 1 - Standard AP (decreasing)
    # 10 5 0 -5 -10, diff = -5, next = -15
    await run_test_case(5, [10, 5, 0, -5, -10], -15)

    # Test Case 2: Example 2 - Constant sequence
    # 1 1 1 1, diff = 0, next = 1
    await run_test_case(4, [1, 1, 1, 1], 1)

    # Test Case 3: Example 3 - Not an AP
    # 5 1 -5, diffs: -4, -6 (breaks), so return last = -5
    await run_test_case(3, [5, 1, -5], -5)

    # Test Case 4: Example 4 - Standard AP (increasing)
    # 900 1000, diff = 100, next = 1100
    await run_test_case(2, [900, 1000], 1100)
    
    # Test Case 5: Negative values AP
    # -1000 -995 -990, diff = 5, next = -985
    await run_test_case(3, [-1000, -995, -990], -985)
    
    # Test Case 6: AP with max range
    # 900 1000 1100 (assuming limit), diff = 100, next = 1200
    await run_test_case(3, [900, 1000, 1100], 1200)

    # Test Case 7: Broken AP at the end
    # 1 2 3 5 (diff 1 for first 3, then 2), return last = 5
    await run_test_case(4, [1, 2, 3, 5], 5)

    dut._log.info("All tests passed!")
