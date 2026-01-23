import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_power_set_generator(dut):
    """Test power set generation for 4 elements"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_mask.value = 0
    dut.element_0.value = 0
    dut.element_1.value = 0
    dut.element_2.value = 0
    dut.element_3.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: All 4 elements valid
    print("
Test Case 1: 4 elements (orange=1, red=2, green=3, blue=4)")
    dut.valid_mask.value = 0b1111
    dut.element_0.value = 1   # orange
    dut.element_1.value = 2   # red
    dut.element_2.value = 3   # green
    dut.element_3.value = 4   # blue
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect all outputs
    outputs = []
    current_subset = []
    last_indices = 0
    
    timeout = 100
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.output_done.value:
            break
        if dut.output_valid.value:
            indices = int(dut.output_indices.value)
            element = int(dut.output_element.value)
            # Check if indices changed (new subset)
            if indices != last_indices and last_indices != 0:
                # Start new subset
                outputs.append(current_subset)
                current_subset = []
            current_subset.append(element)
            last_indices = indices
    # Append last subset
    if current_subset:
        outputs.append(current_subset)
    
    # Verify we got 15 non-empty subsets (2^4 - 1)
    print(f"Generated {len(outputs)} subsets")
    print(f"Subsets: {outputs}")
    assert len(outputs) == 15, f"Expected 15 non-empty subsets, got {len(outputs)}"
    
    # Verify specific subsets
    expected_subsets = [
        [1], [2], [1, 2],  # From 0001, 0010, 0011
        [3], [1, 3], [2, 3], [1, 2, 3],  # From 0100, 0101, 0110, 0111
        [4], [1, 4], [2, 4], [1, 2, 4],  # From 1000, 1001, 1010, 1011
        [3, 4], [1, 3, 4], [2, 3, 4], [1, 2, 3, 4]  # From 1100, 1101, 1110, 1111
    ]
    
    for i, (actual, expected) in enumerate(zip(outputs, expected_subsets)):
        print(f"Subset {i}: {actual} (expected {expected})")
        assert actual == expected, f"Subset {i} mismatch: {actual} != {expected}"
    
    print("Test Case 1 passed!")
    
    # Test Case 2: 3 elements valid
    print("
Test Case 2: 3 elements (red=5, green=6, blue=7)")
    dut.valid_mask.value = 0b0111
    dut.element_0.value = 5
    dut.element_1.value = 6
    dut.element_2.value = 7
    dut.element_3.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    outputs = []
    current_subset = []
    last_indices = 0
    
    timeout = 100
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.output_done.value:
            break
        if dut.output_valid.value:
            indices = int(dut.output_indices.value)
            element = int(dut.output_element.value)
            if indices != last_indices and last_indices != 0:
                outputs.append(current_subset)
                current_subset = []
            current_subset.append(element)
            last_indices = indices
    if current_subset:
        outputs.append(current_subset)
    
    print(f"Generated {len(outputs)} subsets")
    print(f"Subsets: {outputs}")
    assert len(outputs) == 7, f"Expected 7 non-empty subsets, got {len(outputs)}"
    print("Test Case 2 passed!")
    
    # Test Case 3: 2 elements valid
    print("
Test Case 3: 2 elements (black=10, orange=11)")
    dut.valid_mask.value = 0b0011
    dut.element_0.value = 10
    dut.element_1.value = 11
    dut.element_2.value = 0
    dut.element_3.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    outputs = []
    current_subset = []
    last_indices = 0
    
    timeout = 100
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.output_done.value:
            break
        if dut.output_valid.value:
            indices = int(dut.output_indices.value)
            element = int(dut.output_element.value)
            if indices != last_indices and last_indices != 0:
                outputs.append(current_subset)
                current_subset = []
            current_subset.append(element)
            last_indices = indices
    if current_subset:
        outputs.append(current_subset)
    
    print(f"Generated {len(outputs)} subsets")
    print(f"Subsets: {outputs}")
    assert len(outputs) == 3, f"Expected 3 non-empty subsets, got {len(outputs)}"
    assert outputs == [[10], [11], [10, 11]], f"Unexpected outputs: {outputs}"
    print("Test Case 3 passed!")
    
    print("
All tests passed!")

@cocotb.test()
async def test_power_set_empty(dut):
    """Test with no valid elements"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_mask.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
Test Case 4: No valid elements")
    dut.valid_mask.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not dut.output_done.value and cycles < 50:
        await RisingEdge(dut.clk)
        cycles += 1
    
    # Should finish quickly with no outputs
    assert dut.output_done.value, "Module should finish for empty set"
    print("Empty set test passed!")
