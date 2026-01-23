import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_get_positive(dut):
    """Test filtering positive numbers from fixed-width array"""
    
    # Test case 1: [-1, -2, 4, 5, 6] -> [4, 5, 6]
    dut.data_in[0].value = 255  # -1
    dut.data_in[1].value = 254  # -2
    dut.data_in[2].value = 4    # 4
    dut.data_in[3].value = 5    # 5
    dut.data_in[4].value = 6    # 6
    dut.data_in[5].value = 0
    dut.data_in[6].value = 0
    dut.data_in[7].value = 0
    dut.count.value = 5
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 3, f"Expected 3 positives, got {dut.out_count.value}"
    assert dut.data_out_0.value == 4, f"Expected data_out_0=4, got {dut.data_out_0.value}"
    assert dut.data_out_1.value == 5, f"Expected data_out_1=5, got {dut.data_out_1.value}"
    assert dut.data_out_2.value == 6, f"Expected data_out_2=6, got {dut.data_out_2.value}"
    print("Test 1 passed: [-1, -2, 4, 5, 6] -> [4, 5, 6]")
    
    # Test case 2: [5, 3, -5, 2, 3, 3, 9, 0, 123, 1, -10] -> [5, 3, 2, 3, 3, 9, 123, 1]
    # Scale to 8 elements: [5, 3, -5, 2, 3, 3, 9, 0]
    dut.data_in[0].value = 5
    dut.data_in[1].value = 3
    dut.data_in[2].value = 251  # -5
    dut.data_in[3].value = 2
    dut.data_in[4].value = 3
    dut.data_in[5].value = 3
    dut.data_in[6].value = 9
    dut.data_in[7].value = 0
    dut.count.value = 8
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 7, f"Expected 7 positives, got {dut.out_count.value}"
    assert dut.data_out_0.value == 5
    assert dut.data_out_1.value == 3
    assert dut.data_out_2.value == 2
    assert dut.data_out_3.value == 3
    assert dut.data_out_4.value == 3
    assert dut.data_out_5.value == 9
    assert dut.data_out_6.value == 0  # 0 is not positive, so next slot empty
    print("Test 2 passed: [5, 3, -5, 2, 3, 3, 9, 0] -> [5, 3, 2, 3, 3, 9]")
    
    # Test case 3: [-1, -2] -> []
    dut.data_in[0].value = 255  # -1
    dut.data_in[1].value = 254  # -2
    dut.data_in[2].value = 0
    dut.data_in[3].value = 0
    dut.data_in[4].value = 0
    dut.data_in[5].value = 0
    dut.data_in[6].value = 0
    dut.data_in[7].value = 0
    dut.count.value = 2
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 0, f"Expected 0 positives, got {dut.out_count.value}"
    print("Test 3 passed: [-1, -2] -> []")
    
    # Test case 4: [] -> []
    dut.data_in[0].value = 0
    dut.data_in[1].value = 0
    dut.data_in[2].value = 0
    dut.data_in[3].value = 0
    dut.data_in[4].value = 0
    dut.data_in[5].value = 0
    dut.data_in[6].value = 0
    dut.data_in[7].value = 0
    dut.count.value = 0
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 0, f"Expected 0 positives, got {dut.out_count.value}"
    print("Test 4 passed: [] -> []")
    
    # Test case 5: Edge case with max values
    dut.data_in[0].value = 127  # max positive
    dut.data_in[1].value = 128  # -128 (negative)
    dut.data_in[2].value = 1
    dut.data_in[3].value = 255  # -1
    dut.data_in[4].value = 255
    dut.data_in[5].value = 255
    dut.data_in[6].value = 255
    dut.data_in[7].value = 255
    dut.count.value = 4
    await Timer(10, units='ns')
    
    assert dut.out_count.value == 2, f"Expected 2 positives, got {dut.out_count.value}"
    assert dut.data_out_0.value == 127
    assert dut.data_out_1.value == 1
    print("Test 5 passed: [127, -128, 1, -1] -> [127, 1]")
    
    print("
=== Summary: 5/5 tests passed ===")