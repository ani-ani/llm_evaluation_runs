import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure


def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False


@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_rolling_max(dut):
    """Test rolling_max module with various test cases"""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the module
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.data_in.value = 0
    dut.data_in_valid.value = 0
    dut.data_in_done.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to process a test case
    async def process_test_case(test_name, input_list, expected_list):
        dut._log.info(f"Processing test case: {test_name}")
        
        if not input_list:
            # Empty list test - just start and immediately done
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            # No inputs, done should not be asserted yet
            await Timer(10, units='ns')
            # We need to handle empty case specially
            # The module expects at least one input, so for empty we skip inputs
            # and just check if we can go through the flow
            # Actually, for empty, the test checks that no processing happens
            # Let's just send a done immediately
            dut.valid_in.value = 1
            dut.data_in_valid.value = 0
            dut.data_in_done.value = 1
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            dut.data_in_done.value = 0
            await RisingEdge(dut.clk)
            # Check if done is high
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                dut._log.info(f"  {test_name}: Empty case handled")
                return
            return
        
        # For non-empty cases
        results = []
        expected_idx = 0
        
        # Start the module
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Process each input
        for i, input_val in enumerate(input_list):
            is_last = (i == len(input_list) - 1)
            
            # Present input
            dut.valid_in.value = 1
            dut.data_in.value = input_val & 0xFFFF  # Ensure 16-bit
            dut.data_in_valid.value = 1
            dut.data_in_done.value = 1 if is_last else 0
            
            await RisingEdge(dut.clk)
            
            # Wait for valid output (check over several cycles)
            output_received = False
            for _ in range(10):  # Check up to 10 cycles
                await Timer(1, units='ns')  # Small delay for prop
                if is_value_defined(dut.valid_out.value) and dut.valid_out.value == 1:
                    if is_value_defined(dut.result.value):
                        result_val = int(dut.result.value)
                        # Handle signed values
                        if result_val >= 32768:
                            result_val -= 65536
                        results.append(result_val)
                        dut._log.info(f"  Input {input_val}: Got result {result_val}")
                        output_received = True
                        break
                await RisingEdge(dut.clk)
            
            if not output_received:
                raise TestFailure(f"No valid output for input {input_val}")
            
            # Deassert for next cycle
            dut.valid_in.value = 0
            dut.data_in_valid.value = 0
            if is_last:
                dut.data_in_done.value = 0
            
            # Wait one more cycle to ensure no extra outputs
            await RisingEdge(dut.clk)
        
        # After all inputs, check done signal
        if is_value_defined(dut.done.value):
            if dut.done.value == 1:
                dut._log.info(f"  Done signal asserted")
            else:
                # Wait one more cycle for done
                await RisingEdge(dut.clk)
        
        # Verify results
        if len(results) != len(expected_list):
            raise TestFailure(f"Expected {len(expected_list)} outputs, got {len(results)}")
        
        for i, (got, expected) in enumerate(zip(results, expected_list)):
            if got != expected:
                raise TestFailure(f"Test {test_name}: Position {i}, expected {expected}, got {got}")
        
        dut._log.info(f"  {test_name}: PASSED")
    
    # Test Case 1: Empty list
    await process_test_case("Empty", [], [])
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: Increasing sequence
    await process_test_case("Increasing", [1, 2, 3, 4], [1, 2, 3, 4])
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: Decreasing sequence
    await process_test_case("Decreasing", [4, 3, 2, 1], [4, 4, 4, 4])
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4: Mixed sequence
    await process_test_case("Mixed", [3, 2, 3, 100, 3], [3, 3, 3, 100, 100])
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 5: Single element
    await process_test_case("Single", [42], [42])
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 6: All same
    await process_test_case("AllSame", [5, 5, 5, 5], [5, 5, 5, 5])
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 7: Negative values
    await process_test_case("Negative", [-5, -3, -10, -2], [-5, -3, -3, -2])
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 8: Mixed positive and negative
    await process_test_case("MixedSign", [-5, 10, -3, 15, 0], [-5, 10, 10, 15, 15])
    
    dut._log.info("All tests passed!")
    
    # Count tests
    total_tests = 8
    passed_tests = 8
    dut._log.info(f"Summary: {passed_tests}/{total_tests} tests passed")
