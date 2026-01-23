import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_find_min_sublist(dut):
    """Test find_min_sublist module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_sublists.value = 0
    for i in range(4):
        dut.sublist_lengths[i].value = 0
    for i in range(32):
        dut.all_elements[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [[1],[1,2],[1,2,3]] -> [1] at index 0
    dut.num_sublists.value = 3
    dut.sublist_lengths[0].value = 1
    dut.sublist_lengths[1].value = 2
    dut.sublist_lengths[2].value = 3
    dut.sublist_lengths[3].value = 0
    dut.all_elements[0].value = 1
    dut.all_elements[8].value = 1
    dut.all_elements[9].value = 2
    dut.all_elements[16].value = 1
    dut.all_elements[17].value = 2
    dut.all_elements[18].value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (should take 6 cycles total: 1 idle + 4 processing + 1 done)
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.min_index.value == 0, f"Expected min_index=0, got {int(dut.min_index.value)}"
    assert dut.min_length.value == 1, f"Expected min_length=1, got {int(dut.min_length.value)}"
    print("Test 1 passed: [[1],[1,2],[1,2,3]] -> index 0, length 1")
    
    # Test 2: [[1,1],[1,1,1],[1,2,7,8]] -> [1,1] at index 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.num_sublists.value = 3
    dut.sublist_lengths[0].value = 2
    dut.sublist_lengths[1].value = 3
    dut.sublist_lengths[2].value = 4
    dut.all_elements[0].value = 1
    dut.all_elements[1].value = 1
    dut.all_elements[8].value = 1
    dut.all_elements[9].value = 1
    dut.all_elements[10].value = 1
    dut.all_elements[16].value = 1
    dut.all_elements[17].value = 2
    dut.all_elements[18].value = 7
    dut.all_elements[19].value = 8
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.min_index.value == 0, f"Expected min_index=0, got {int(dut.min_index.value)}"
    assert dut.min_length.value == 2, f"Expected min_length=2, got {int(dut.min_length.value)}"
    print("Test 2 passed: [[1,1],[1,1,1],[1,2,7,8]] -> index 0, length 2")
    
    # Test 3: [['x'],['x','y'],['x','y','z']] -> ['x'] at index 0
    # ASCII: 'x'=120, 'y'=121, 'z'=122
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.num_sublists.value = 3
    dut.sublist_lengths[0].value = 1
    dut.sublist_lengths[1].value = 2
    dut.sublist_lengths[2].value = 3
    dut.all_elements[0].value = 120  # 'x'
    dut.all_elements[8].value = 120  # 'x'
    dut.all_elements[9].value = 121  # 'y'
    dut.all_elements[16].value = 120 # 'x'
    dut.all_elements[17].value = 121 # 'y'
    dut.all_elements[18].value = 122 # 'z'
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.min_index.value == 0, f"Expected min_index=0, got {int(dut.min_index.value)}"
    assert dut.min_length.value == 1, f"Expected min_length=1, got {int(dut.min_length.value)}"
    print("Test 3 passed: [['x'],['x','y'],['x','y','z']] -> index 0, length 1")
    
    # Test 4: Edge case - equal lengths, should return first
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.num_sublists.value = 2
    dut.sublist_lengths[0].value = 2
    dut.sublist_lengths[1].value = 2
    dut.all_elements[0].value = 5
    dut.all_elements[1].value = 6
    dut.all_elements[8].value = 7
    dut.all_elements[9].value = 8
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    assert dut.min_index.value == 0, f"Expected min_index=0 (first), got {int(dut.min_index.value)}"
    print("Test 4 passed: equal lengths -> index 0")
    
    # Test 5: Last sublist is shortest
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.num_sublists.value = 3
    dut.sublist_lengths[0].value = 3
    dut.sublist_lengths[1].value = 4
    dut.sublist_lengths[2].value = 1
    dut.all_elements[0].value = 1
    dut.all_elements[1].value = 2
    dut.all_elements[2].value = 3
    dut.all_elements[8].value = 4
    dut.all_elements[9].value = 5
    dut.all_elements[10].value = 6
    dut.all_elements[11].value = 7
    dut.all_elements[16].value = 9
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    assert dut.min_index.value == 2, f"Expected min_index=2, got {int(dut.min_index.value)}"
    assert dut.min_length.value == 1, f"Expected min_length=1, got {int(dut.min_length.value)}"
    print("Test 5 passed: [[1,2,3],[4,5,6,7],[9]] -> index 2, length 1")
    
    print("
=== Summary: 5/5 tests passed ===")
