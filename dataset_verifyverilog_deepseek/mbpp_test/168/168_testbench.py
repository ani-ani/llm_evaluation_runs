import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_frequency(dut):
    # Pad test arrays to 8 elements with 0
    test_cases = [
        ([1,2,3,0,0,0,0,0], 4, 0),
        ([1,2,2,3,3,3,4,0], 3, 3),
        ([0,1,2,3,1,2,0,0], 1, 2),
        ([5,5,5,5,5,5,5,5], 5, 8),  # All match case
        ([9,8,7,6,5,4,3,2], 1, 0)   # No match case
    ]
    
    passed = 0
    for arr, x_val, expected in test_cases:
        for i in range(8):
            dut.list_array[i].value = arr[i]
        dut.x.value = x_val
        await Timer(1, units='ns')
        actual = dut.count.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {x_val} in {arr[:6]}... = {actual}")
        else:
            dut._log.error(f"FAIL: {x_val} in {arr[:6]}... = {actual}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"