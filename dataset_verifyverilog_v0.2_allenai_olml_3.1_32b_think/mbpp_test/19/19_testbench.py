import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_duplicate_finder(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to run a test case
    async def run_test(arr, expected_result, test_name):
        dut._log.info(f"Running {test_name}")
        
        # Pack array into the vector. 
        # Verilog expects [N-1:0][W-1:0]. 
        # In cocotb, we can assign a list of integers if the simulator supports it, 
        # or we construct the bit vector.
        # Let's try passing a list of integers directly, cocotb usually handles this well for packed arrays.
        # If that fails, we bit-pack manually.
        # Format: array_in[0] is the least significant part? 
        # Usually [N-1:0] means index N-1 is MSB.
        # Let's construct a binary value: value = sum(arr[i] << (i*W))
        
        packed_val = 0
        for i in range(len(arr)):
            packed_val |= (arr[i] << (i * 32))
        
        dut.array_in.value = packed_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            raise TestFailure(f"{test_name}: Timeout waiting for done")

        # Check result
        actual = int(dut.result.value)
        if actual != expected_result:
            raise TestFailure(f"{test_name}: Expected {expected_result}, got {actual}")
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)

    # Test Case 1: No duplicates [1, 2, 3, 4, 5]
    # Array size N=8, so we need 8 elements. Padding with 0s.
    await run_test([1, 2, 3, 4, 5, 0, 0, 0], 0, "Test 1: No Duplicates")

    # Test Case 2: Has duplicates [1, 2, 3, 4, 4]
    await run_test([1, 2, 3, 4, 4, 0, 0, 0], 1, "Test 2: Duplicate at end")

    # Test Case 3: All duplicates [1, 1, 2, 2, 3, 3, 4, 4]
    # Note: The input array in Python is length 9, but we limit to N=8.
    # We use the first 8 elements: [1, 1, 2, 2, 3, 3, 4, 4]
    await run_test([1, 1, 2, 2, 3, 3, 4, 4], 1, "Test 3: All Pairs")

    # Test Case 4: Edge case - all zeros
    await run_test([0, 0, 0, 0, 0, 0, 0, 0], 1, "Test 4: All Zeros")

    # Test Case 5: Unique large numbers
    await run_test([100, 200, 300, 400, 500, 600, 700, 800], 0, "Test 5: Unique Large")

    dut._log.info("All tests passed!")