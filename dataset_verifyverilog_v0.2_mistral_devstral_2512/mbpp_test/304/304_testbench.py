import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_find_element_after_rotations(dut):
    """Test finding element after undoing rotations"""
    
    # Helper to convert Python list to fixed-size array
    def pack_array(arr, size=8, width=3):
        result = 0
        for i, val in enumerate(arr):
            result |= (val & ((1 << width) - 1)) << (i * width)
        return result
    
    # Helper to set array inputs
    def set_array(dut, arr):
        for i in range(min(len(arr), 8)):
            dut.array_data[i].value = arr[i]
        # Set remaining to 0
        for i in range(len(arr), 8):
            dut.array_data[i].value = 0
    
    # Helper to set rotation ranges
    def set_ranges(dut, ranges):
        # Initialize all to 0
        for i in range(4):
            dut.rotation_ranges_left[i].value = 0
            dut.rotation_ranges_right[i].value = 0
        # Set provided ranges
        for i, (l, r) in enumerate(ranges):
            if i < 4:
                dut.rotation_ranges_left[i].value = l
                dut.rotation_ranges_right[i].value = r
    
    # Test Case 1
    dut._log.info("Test 1: Array [1,2,3,4,5], Ranges [[0,2],[0,3]], Rotations=2, Index=1")
    set_array(dut, [1,2,3,4,5])
    set_ranges(dut, [[0,2],[0,3]])
    dut.num_rotations.value = 2
    dut.index_final.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 3, f"Expected 3, got {dut.result.value}"
    dut._log.info("Test 1 PASSED")
    
    # Test Case 2
    dut._log.info("Test 2: Array [1,2,3,4], Ranges [[0,1],[0,2]], Rotations=1, Index=2")
    set_array(dut, [1,2,3,4])
    set_ranges(dut, [[0,1],[0,2]])
    dut.num_rotations.value = 1
    dut.index_final.value = 2
    await Timer(10, units='ns')
    assert dut.result.value == 3, f"Expected 3, got {dut.result.value}"
    dut._log.info("Test 2 PASSED")
    
    # Test Case 3
    dut._log.info("Test 3: Array [1,2,3,4,5,6], Ranges [[0,1],[0,2]], Rotations=1, Index=1")
    set_array(dut, [1,2,3,4,5,6])
    set_ranges(dut, [[0,1],[0,2]])
    dut.num_rotations.value = 1
    dut.index_final.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Expected 1, got {dut.result.value}"
    dut._log.info("Test 3 PASSED")
    
    # Test Case 4: Edge case - no rotations
    dut._log.info("Test 4: Array [5,6,7,8], No rotations, Index=2")
    set_array(dut, [5,6,7,8])
    set_ranges(dut, [])
    dut.num_rotations.value = 0
    dut.index_final.value = 2
    await Timer(10, units='ns')
    assert dut.result.value == 7, f"Expected 7, got {dut.result.value}"
    dut._log.info("Test 4 PASSED")
    
    # Test Case 5: Single rotation affecting index
    dut._log.info("Test 5: Array [10,11,12,13], Ranges [[0,1]], Rotations=1, Index=1")
    set_array(dut, [10,11,12,13])
    set_ranges(dut, [[0,1]])
    dut.num_rotations.value = 1
    dut.index_final.value = 1
    await Timer(10, units='ns')
    # Original index: 1 is in [0,1], index!=0, so becomes 0. arr[0]=10
    assert dut.result.value == 10, f"Expected 10, got {dut.result.value}"
    dut._log.info("Test 5 PASSED")
    
    dut._log.info("All 5 tests passed!")