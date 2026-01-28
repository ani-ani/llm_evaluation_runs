import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_strange_sort(dut):
    """
    Test the strange_sort module with various test cases.
    """
    # Helper function to check if a value is defined (not X or Z)
    def is_value_defined(value):
        try:
            int(value)
            return True
        except ValueError:
            return False

    # Clock generation (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    
    # Initialize array to 0
    # Check if array is flat or 2D
    # We assume dut.arr[i] is accessible based on prompt spec
    try:
        # Try accessing as 2D array (dut.arr[i])
        for i in range(8):
            dut.arr[i].value = 0
        is_flat = False
    except (AttributeError, TypeError):
        # Fallback for flat packed array (unlikely given prompt spec, but good practice)
        # Or individual ports arr_0, arr_1...
        # If we can't access dut.arr[i], we might need to set them individually
        # But the prompt said "input [7:0] arr [0:7]", so dut.arr should work.
        # If it fails, we skip setting array for reset (it's usually ignored during reset anyway)
        pass

    # Wait for 2 clock cycles during reset
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (input_list, expected_output_list)
    # Note: Input lists contain signed integers.
    # We must convert negative numbers to 8-bit unsigned 2's complement for assignment.
    test_cases = [
        ([1, 2, 3, 4], [1, 4, 2, 3]),
        ([5, 6, 7, 8, 9], [5, 9, 6, 8, 7]),
        ([1, 2, 3, 4, 5], [1, 5, 2, 4, 3]),
        ([5, 6, 7, 8, 9, 1], [1, 9, 5, 8, 6, 7]),
        ([5, 5, 5, 5], [5, 5, 5, 5]),
        ([], []),
        ([1, 2, 3, 4, 5, 6, 7, 8], [1, 8, 2, 7, 3, 6, 4, 5]),
        ([0, 2, 2, 2, 5, 5, -5, -5], [-5, 5, -5, 5, 0, 2, 2, 2]),
        ([111, 111], [111, 111])
    ]

    total_tests = len(test_cases)
    passed_tests = 0

    for i, (input_list, expected_list) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: {input_list}")
        
        # Load inputs
        # We need to handle the array assignment carefully
        # Based on Rule 11 and 12, we should handle array assignment robustly.
        # We'll try dut.arr[i].value first, as per prompt spec "input [7:0] arr [0:7]"
        
        len_val = len(input_list)
        dut.len.value = len_val
        
        # Reset array values to 0 for indices not used (optional but cleaner)
        for j in range(8):
            val = 0
            if j < len_val:
                raw_val = input_list[j]
                if raw_val < 0:
                    val = (1 << 8) + raw_val  # 2's complement
                else:
                    val = raw_val
            
            # Try to assign to dut.arr[j]
            try:
                dut.arr[j].value = val
            except (AttributeError, TypeError):
                # If arr is not indexable, maybe it's a flat signal or named ports
                # This is a fallback, though we expect dut.arr[j] based on prompt
                pass
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect outputs
        collected_outputs = []
        
        if len_val == 0:
            # Empty list case
            # We expect no output or done pulse immediately
            # Wait a few cycles to ensure no spurious outputs
            for _ in range(5):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.result.value) and is_value_defined(dut.done.value):
                    if dut.done.value == 1:
                        raise TestFailure(f"Test {i+1}: Unexpected done pulse for empty list")
            passed_tests += 1
            dut._log.info(f"Test Case {i+1} Passed (Empty)")
            continue

        # Wait for outputs
        # We expect 'len_val' pulses on 'done'.
        # We will wait for 'done' to go high, capture 'result', then wait for 'done' to go low.
        # Repeat until we have 'len_val' elements.
        
        cycles_spent = 0
        max_cycles = 200  # Should be enough for 8 elements sorting + output
        
        while len(collected_outputs) < len_val and cycles_spent < max_cycles:
            await RisingEdge(dut.clk)
            cycles_spent += 1
            
            if not is_value_defined(dut.done.value) or not is_value_defined(dut.result.value):
                continue
                
            if dut.done.value == 1:
                # Capture result
                val = int(dut.result.value)
                
                # Handle 2's complement conversion for negative numbers if needed for comparison
                # The 'val' is an unsigned integer. 
                # If the Verilog outputs a signed value, it might be sign-extended or handled differently.
                # But since output is [7:0], it's just the byte.
                # We'll store the integer as is, and handle conversion when comparing.
                collected_outputs.append(val)
                
                # Wait for done to go low to avoid double counting the same pulse
                # We do this by waiting a few cycles or checking low in the next loop iteration
                # The loop iteration handles this naturally by checking done == 1 again
                # If done stays high for multiple cycles (bad), we might double count.
                # So we wait for done to go low.
                timeout = 0
                while dut.done.value == 1 and timeout < 10:
                    await RisingEdge(dut.clk)
                    cycles_spent += 1
                    timeout += 1
        
        # Verification
        if len(collected_outputs) != len_val:
            raise TestFailure(f"Test {i+1}: Expected {len_val} outputs, got {len(collected_outputs)}. Collected: {collected_outputs}")
        
        # Convert expected list to 8-bit unsigned 2's complement for comparison
        expected_ints = []
        for x in expected_list:
            if x < 0:
                expected_ints.append((1 << 8) + x)
            else:
                expected_ints.append(x)
        
        # Check values
        success = True
        for k in range(len_val):
            if collected_outputs[k] != expected_ints[k]:
                # Detailed error
                dut._log.error(f"Test {i+1} Mismatch at index {k}: Expected {expected_ints[k]} (signed {expected_list[k]}), Got {collected_outputs[k]}")
                success = False
        
        if success:
            passed_tests += 1
            dut._log.info(f"Test Case {i+1} Passed")
        else:
            raise TestFailure(f"Test {i+1} Failed")

    dut._log.info(f"Summary: {passed_tests}/{total_tests} tests passed")
    if passed_tests != total_tests:
        raise TestFailure(f"Only {passed_tests} of {total_tests} tests passed.")
