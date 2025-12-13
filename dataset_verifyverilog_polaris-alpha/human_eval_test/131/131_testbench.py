import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_odd_product(dut):
    test_cases = [
        (5, 5),
        (54, 5),
        (120, 1),
        (5014, 5),
        (98765, 315),
        (8765, 35),   # Original 5576543 downscaled
        (2468, 0)
    ]
    
    passed = 0
    for num, expected in test_cases:
        dut.num.value = num
        await Timer(1, units='ns')
        result = dut.product.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {num} => {result}")
        else:
            dut._log.error(f"FAIL: {num} => {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)