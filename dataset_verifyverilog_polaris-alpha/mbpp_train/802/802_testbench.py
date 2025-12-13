import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_rotation_counter(dut):
    # Pad test cases to 8 elements (unused ignored)
    test_cases = [
        ([3,2,1,0,0,0,0,0], 3, 1),
        ([4,5,1,2,3,0,0,0], 5, 2),
        ([7,8,9,1,2,3,0,0], 6, 3),
        ([1,2,3,0,0,0,0,0], 3, 0),
        ([1,3,2,0,0,0,0,0], 3, 2),
        ([15,1,0,0,0,0,0,0], 2, 1)  # Edge case: max value
    ]
    
    passed = 0
    for arr, size, expected in test_cases:
        dut.array_size.value = size
        dut.arr0.value = arr[0]
        dut.arr1.value = arr[1]
        dut.arr2.value = arr[2]
        dut.arr3.value = arr[3]
        dut.arr4.value = arr[4]
        dut.arr5.value = arr[5]
        dut.arr6.value = arr[6]
        dut.arr7.value = arr[7]
        await Timer(1, units='ns')
        actual = int(dut.rotation_count.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {arr[:size]} size={size} → {actual}")
        else:
            dut._log.error(f"FAIL: {arr[:size]} size={size} → {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")