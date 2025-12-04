import cocotb
from cocotb.triggers import Timer

# Reference Python implementation
def ref_model(arr):
    return sum((((i+1)*(4-i)+1)//2)*val for i,val in enumerate(arr))

@cocotb.test()
async def test_odd_length_sum(dut):
    test_cases = [
        ([1,2,4,0], 14),  # Original [1,2,4] padded
        ([1,2,1,2], 15),  # Original [1,2,1,2]
        ([1,7,0,0], 8),   # Original [1,7] padded
        ([5,5,5,5], 50),  # All same
        ([0,0,0,0], 0),   # Zero case
        ([15,15,15,15], 145)  # Max input test
    ]
    passed = 0
    for arr, expected in test_cases:
        dut.arr_0.value = arr[0]
        dut.arr_1.value = arr[1]
        dut.arr_2.value = arr[2]
        dut.arr_3.value = arr[3]
        await Timer(1, units='ns')
        actual = dut.sum.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {arr} -> {actual}")
        else:
            dut._log.error(f"FAIL: {arr} -> {actual} (expected {expected})")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")