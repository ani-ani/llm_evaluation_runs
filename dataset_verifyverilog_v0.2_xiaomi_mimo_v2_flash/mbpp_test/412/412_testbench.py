import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_remove_odd(dut):
    """Test remove_odd module with various test cases"""
    
    print("
=== Test 1: [1,2,3] -> [2] ===")
    dut.data_in.value = [1, 2, 3, 0, 0, 0, 0, 0]
    dut.valid_count.value = 3
    await Timer(10, units='ns')
    result = [int(dut.data_out[i]) for i in range(8)]
    count = int(dut.out_count.value)
    print(f"Output: {result[:count]}, Count: {count}")
    assert count == 1, f"Expected count 1, got {count}"
    assert result[0] == 2, f"Expected [2], got {result[:count]}"
    
    print("
=== Test 2: [2,4,6] -> [2,4,6] ===")
    dut.data_in.value = [2, 4, 6, 0, 0, 0, 0, 0]
    dut.valid_count.value = 3
    await Timer(10, units='ns')
    result = [int(dut.data_out[i]) for i in range(8)]
    count = int(dut.out_count.value)
    print(f"Output: {result[:count]}, Count: {count}")
    assert count == 3, f"Expected count 3, got {count}"
    assert result[:3] == [2, 4, 6], f"Expected [2,4,6], got {result[:count]}"
    
    print("
=== Test 3: [10,20,3] -> [10,20] ===")
    dut.data_in.value = [10, 20, 3, 0, 0, 0, 0, 0]
    dut.valid_count.value = 3
    await Timer(10, units='ns')
    result = [int(dut.data_out[i]) for i in range(8)]
    count = int(dut.out_count.value)
    print(f"Output: {result[:count]}, Count: {count}")
    assert count == 2, f"Expected count 2, got {count}"
    assert result[:2] == [10, 20], f"Expected [10,20], got {result[:count]}"
    
    print("
=== Test 4: [1,3,5,7] -> [] ===")
    dut.data_in.value = [1, 3, 5, 7, 0, 0, 0, 0]
    dut.valid_count.value = 4
    await Timer(10, units='ns')
    result = [int(dut.data_out[i]) for i in range(8)]
    count = int(dut.out_count.value)
    print(f"Output: {result[:count]}, Count: {count}")
    assert count == 0, f"Expected count 0, got {count}"
    
    print("
=== Test 5: Mixed values [15,16,17,18,19,20] -> [16,18,20] ===")
    dut.data_in.value = [15, 16, 17, 18, 19, 20, 0, 0]
    dut.valid_count.value = 6
    await Timer(10, units='ns')
    result = [int(dut.data_out[i]) for i in range(8)]
    count = int(dut.out_count.value)
    print(f"Output: {result[:count]}, Count: {count}")
    assert count == 3, f"Expected count 3, got {count}"
    assert result[:3] == [16, 18, 20], f"Expected [16,18,20], got {result[:count]}"
    
    print("
=== Test 6: All even [0,2,254,255] -> [0,2,254] ===")
    dut.data_in.value = [0, 2, 254, 255, 0, 0, 0, 0]
    dut.valid_count.value = 4
    await Timer(10, units='ns')
    result = [int(dut.data_out[i]) for i in range(8)]
    count = int(dut.out_count.value)
    print(f"Output: {result[:count]}, Count: {count}")
    assert count == 3, f"Expected count 3, got {count}"
    assert result[:3] == [0, 2, 254], f"Expected [0,2,254], got {result[:count]}"
    
    passed = 6
    total = 6
    print(f"
*** {passed}/{total} tests passed ***")