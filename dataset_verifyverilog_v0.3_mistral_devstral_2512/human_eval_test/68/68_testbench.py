import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check for defined values
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to find expected result for verification
def find_expected(arr):
    min_val = None
    min_idx = -1
    for i, val in enumerate(arr):
        if val % 2 == 0:  # Even check
            if min_val is None or val < min_val:
                min_val = val
                min_idx = i
    if min_val is None:
        return (0, 0, 0) # value, index, found
    else:
        return (min_val, min_idx, 1)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_pluck_even(dut):
    """
    Test the pluck_even module for finding smallest even value and index.
    """
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz
    cocotb.start_soon(clock.start())

    # Reset Sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    # Initialize array inputs to 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define Test Cases
    # Format: (name, list of 8 integers, expected_found, expected_val, expected_idx)
    # We pad lists shorter than 8 with zeros if needed, or just fill remaining with random values (they shouldn't matter if logic is correct)
    # Note: The prompt says array is 8 elements. We must provide 8 inputs.
    test_cases = [
        ("Case 1", [4, 2, 3, 0, 0, 0, 0, 0], 1, 2, 1),
        ("Case 2", [1, 2, 3, 0, 0, 0, 0, 0], 1, 2, 1),
        ("Case 3", [0, 0, 0, 0, 0, 0, 0, 0], 1, 0, 0), # Empty in prompt implies no evens, but here 0 is even. Assuming 0 is allowed. Case 3 is [], which is no data. We simulate empty by filling with odds.
        ("Case 4", [5, 0, 3, 0, 4, 2, 0, 0], 1, 0, 1),
        ("Case 5", [1, 2, 3, 0, 5, 3, 0, 0], 1, 0, 3),
        ("Case 6", [5, 4, 8, 4, 8, 0, 0, 0], 1, 4, 1),
        ("Case 7", [7, 6, 7, 1, 0, 0, 0, 0], 1, 6, 1),
        ("Case 8 (No Evens)", [1, 3, 5, 7, 9, 11, 13, 15], 0, 0, 0),
    ]

    dut._log.info("Starting Tests...")
    passed = 0
    total = len(test_cases)

    for name, arr_vals, exp_found, exp_val, exp_idx in test_cases:
        dut._log.info(f"Running test: {name}")
        
        # Load inputs
        for i in range(8):
            dut.arr[i].value = arr_vals[i]
        
        # Pulse Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for Done with timeout logic
        max_cycles = 20
        done_seen = False
        
        for cycle in range(max_cycles):
            if not is_value_defined(dut.done.value):
                dut._log.warning(f"Done signal undefined in cycle {cycle}")
                await RisingEdge(dut.clk)
                continue
            
            if dut.done.value == 1:
                done_seen = True
                break
            await RisingEdge(dut.clk)
        
        if not done_seen:
            raise TestFailure(f"{name}: Done signal not asserted within {max_cycles} cycles")

        # Check Outputs
        if not is_value_defined(dut.found.value):
             raise TestFailure(f"{name}: Found signal undefined")
        
        found = int(dut.found.value)
        
        if found != exp_found:
             raise TestFailure(f"{name}: Expected found={exp_found}, got {found}")
        
        if found == 1:
            if not is_value_defined(dut.result_value.value):
                 raise TestFailure(f"{name}: result_value undefined")
            if not is_value_defined(dut.result_index.value):
                 raise TestFailure(f"{name}: result_index undefined")
            
            val = int(dut.result_value.value)
            idx = int(dut.result_index.value)
            
            if val != exp_val or idx != exp_idx:
                 raise TestFailure(f"{name}: Expected ({exp_val}, {exp_idx}), got ({val}, {idx})")
        
        dut._log.info(f"{name}: PASSED")
        passed += 1
        await RisingEdge(dut.clk) # Spacing

    dut._log.info(f"\nSUMMARY: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Some tests failed ({passed}/{total})")