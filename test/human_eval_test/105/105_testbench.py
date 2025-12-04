import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_sorter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (input, expected_output, expected_count)
    test_cases = [
        # Original test case 1
        ([2, 1, 1, 4, 5, 8, 2, 3], [8,5,4,3,2,2,1,1], 8),
        # Empty array case
        ([0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], 0),
        # Test case with invalid numbers
        ([1, -1, 55, 0, 0, 0, 0, 0], [1,0,0,0,0,0,0,0], 1),
        # Edge case from problem
        ([1, -1, 3, 2, 0,0,0,0], [3,2,1,0,0,0,0,0], 3),
        # Another sample case
        ([9, 4, 8, 0,0,0,0,0], [9,8,4,0,0,0,0,0], 3)
    ]
    
    passed = 0
    for idx, (in_arr, expected, count) in enumerate(test_cases):
        # Load inputs
        for i in range(8):
            dut.arr[i].value = in_arr[i]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (16 cycles)
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        if dut.done.value != 1:
            dut._log.error(f"Test {idx}: Done signal not asserted")
        else:
            # Check valid count
            valid_count = dut.valid_count.value.integer
            if valid_count != count:
                dut._log.error(f"Test {idx}: Valid count {valid_count} != expected {count}")
            
            # Check result array
            errors = []
            for i in range(8):
                actual = dut.result[i].value.integer
                exp = expected[i]
                if actual != exp:
                    errors.append(f"Element {i}: {actual} != {exp}")
            
            if not errors and valid_count == count:
                passed += 1
                dut._log.info(f"Test {idx} PASSED")
            else:
                dut._log.error(f"Test {idx} FAILED. Errors: {errors}")
        
        # Wait 2 cycles between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"RESULTS: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)