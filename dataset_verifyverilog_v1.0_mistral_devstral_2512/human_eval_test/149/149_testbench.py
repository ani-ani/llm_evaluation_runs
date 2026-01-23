import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_sorted_list_sum(dut):
    """
    Test the sorted_list_sum module.
    Inputs are 8-bit values representing strings.
    Odd length = LSB == 1 (filtered out).
    Sort = Numerical ascending (value).
    """
    def is_value_defined(value):
        try:
            int(value)
            return True
        except ValueError:
            return False

    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset Sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.strings_in[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to format input for display
    def format_input(arr):
        return [f"0x{val:02x}" for val in arr]

    # Test cases
    # Format: (input_list, description)
    # Note: The prompt implies 8 elements are always provided. We pad with 0 if needed.
    # We will map the Python problem logic to the hardware spec:
    # Python: sorted([x for x in lst if len(x)%2==0])
    # Hardware: sorted([x for x in inputs if x%2==0])
    
    test_cases = [
        ([1, 2, 3, 4, 0, 0, 0, 0], "Simple even numbers"),
        ([0xAA, 0xBB, 0xCC, 0xDD, 0, 0, 0, 0], "All even"),
        ([0x01, 0x03, 0x05, 0, 0, 0, 0, 0], "All odd (expect all zeros)"),
        ([10, 5, 20, 15, 2, 0, 0, 0], "Mixed"),
        ([0, 255, 12, 13, 100, 101, 4, 8], "Range 0-255"),
    ]

    passed = 0
    total = len(test_cases)

    for i, (input_vals, desc) in enumerate(test_cases):
        dut._log.info(f"Running Test {i+1}: {desc}")
        
        # Prepare Inputs
        # Ensure we have 8 values, pad with 0 if list is short
        full_input = input_vals + [0] * (8 - len(input_vals))
        
        # Calculate Expected Output
        # Filter: keep if value % 2 == 0
        # Sort: numerical ascending
        valid = [x for x in full_input if x % 2 == 0]
        expected_sorted = sorted(valid)
        
        # Pad expected to length 8 with zeros
        expected_result = expected_sorted + [0] * (8 - len(expected_sorted))
        
        dut._log.info(f"Input: {format_input(full_input)}")
        dut._log.info(f"Expected: {format_input(expected_result)}")

        # Drive Inputs
        for j in range(8):
            dut.strings_in[j].value = full_input[j]
        
        # Pulse Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        done_timeout = 100 # cycles
        done_found = False
        for _ in range(done_timeout):
            if not is_value_defined(dut.done.value):
                await RisingEdge(dut.clk)
                continue
            if dut.done.value == 1:
                done_found = True
                break
            await RisingEdge(dut.clk)
        
        if not done_found:
            dut._log.error(f"Test {i+1} FAILED: Done signal not asserted within timeout")
            continue
        
        # Read Output
        result = []
        valid_output = True
        for j in range(8):
            if not is_value_defined(dut.result[j].value):
                valid_output = False
                break
            result.append(int(dut.result[j].value))
        
        if not valid_output:
            dut._log.error(f"Test {i+1} FAILED: Output contains X/Z")
            continue
        
        # Compare
        if result == expected_result:
            dut._log.info(f"Test {i+1} PASSED")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAILED: Got {format_input(result)}, Expected {format_input(expected_result)}")

    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
