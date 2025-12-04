import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_vector_sum(dut):
    test_cases = [
        ([10,20,30,0], [15,25,35,0], [25,45,65,0]),
        ([1,2,3,0], [5,6,7,0], [6,8,10,0]),
        ([15,20,30,0], [15,45,75,0], [30,65,105,0])
    ]
    
    passed = 0
    for idx, (a, b, expected) in enumerate(test_cases):
        # Pack arrays into 32-bit vectors
        arr1_val = (a[0] << 24) | (a[1] << 16) | (a[2] << 8) | a[3]
        arr2_val = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]
        expected_val = (expected[0] << 24) | (expected[1] << 16) | (expected[2] << 8) | expected[3]
        
        dut.arr1.value = arr1_val
        dut.arr2.value = arr2_val
        await Timer(1, units='ns')
        
        if dut.result.value == expected_val:
            passed += 1
            dut._log.info(f"Test {idx+1} PASSED")
        else:
            actual = [dut.result.value >> 24 & 0xFF, dut.result.value >> 16 & 0xFF,
                      dut.result.value >> 8 & 0xFF, dut.result.value & 0xFF]
            dut._log.error(f"Test {idx+1} FAILED:")
            dut._log.error(f"Input A: {a}, B: {b}")
            dut._log.error(f"Expected: {expected} (0x{expected_val:08x})")
            dut._log.error(f"Got:      {actual} (0x{int(dut.result.value):08x})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")