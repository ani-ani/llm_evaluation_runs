import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_min_heterogeneous(dut):
    """Test the min_heterogeneous module with various inputs."""
    # Create a clock generator (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load.value = 0
    dut.data_in.value = 0
    dut.count.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper task to run a test case
    async def run_test(input_list, expected_min, description):
        print(f"
Running test: {description}")
        
        # Filter for integers only to find expected value
        # Convert to 8-bit representation: strings -> 255, ints -> value (capped at 254)
        # In this test adaptation, we map the Python example data to our hardware format
        hw_inputs = []
        for item in input_list:
            if isinstance(item, int):
                # Clamp to 8 bits (excluding 255)
                val = item if item <= 254 else 254
                hw_inputs.append(val)
            else:
                hw_inputs.append(255)
        
        # Actual count of elements to load
        count_val = len(hw_inputs)
        if count_val > 8:
            print("Warning: Truncating list to 8 elements for hardware")
            hw_inputs = hw_inputs[:8]
            count_val = 8
            
        dut.count.value = count_val
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for IDLE -> LOAD transition (internal logic)
        # Load data sequentially
        for i in range(count_val):
            # Wait for load signal assertion or just drive it
            # Assuming module asserts load ready or we just drive data on specific cycle
            # For this test, we assume the module enters LOAD state and accepts data
            # We wait a few cycles for state machine to settle or poll status
            # Since 'load' input is specified, we drive it
            dut.load.value = 1
            dut.data_in.value = hw_inputs[i]
            await RisingEdge(dut.clk)
        
        dut.load.value = 0
        
        # Wait for computation to complete
        # Timeout mechanism
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 50:
            raise TestFailure(f"Test '{description}' timed out!")
            
        # Check results
        if dut.error.value:
            # Only acceptable if no valid integers existed
            if all(x == 255 for x in hw_inputs):
                print("Result: Error (No valid integers found) - PASS")
            else:
                raise TestFailure(f"Unexpected error flag in test '{description}'")
        else:
            result = int(dut.min_result.value)
            print(f"Expected: {expected_min}, Got: {result}")
            if result != expected_min:
                raise TestFailure(f"Mismatch in test '{description}'")
            print("PASS")

    # Test Case 1: ['Python', 3, 2, 4, 5, 'version'] -> Min 2
    # Map: 255, 3, 2, 4, 5, 255
    await run_test(['Python', 3, 2, 4, 5, 'version'], 2, "Test 1: Mixed list min=2")

    # Test Case 2: ['Python', 15, 20, 25] -> Min 15
    # Map: 255, 15, 20, 25
    await run_test(['Python', 15, 20, 25], 15, "Test 2: Mixed list min=15")

    # Test Case 3: ['Python', 30, 20, 40, 50, 'version'] -> Min 20
    # Map: 255, 30, 20, 40, 50, 255
    await run_test(['Python', 30, 20, 40, 50, 'version'], 20, "Test 3: Mixed list min=20")

    # Test Case 4: Edge case - All strings
    await run_test(['a', 'b', 'c'], 0, "Test 4: All strings (should error or ignore)")
    
    # Test Case 5: Single integer
    await run_test([42], 42, "Test 5: Single integer")

    print("
--- Test Summary ---")
    print("All tests passed.")