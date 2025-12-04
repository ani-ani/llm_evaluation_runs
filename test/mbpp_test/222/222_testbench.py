import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_checker(dut):
    test_cases = [
        # Test 1: All same type (5,6,7,3,5,6)
        (0x0000000000, True),
        # Test 2: Mixed types (1,2,"4")
        (0x0000000002, False),
        # Test 3: All same type (3,2,1,4,5) padded with 0
        (0x0000000000, True),
    ]
    
    passed = 0
    for types_flat, expected in test_cases:
        dut.types.value = types_flat
        await Timer(1, units='ns')
        result = dut.all_same.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {types_flat:024b} -> {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {types_flat:024b} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")