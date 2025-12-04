import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_count_equal(dut):
    test_cases = [
        # (x, y, z, expected)
        (1, 1, 1, 3),    # All equal
        (-1, -2, -3, 0), # All different
        (1, 2, 2, 2),    # Two equal (y,z)
        (5, 5, 3, 2),    # Two equal (x,y)
        (0, 0, 1, 2),    # Two equal (x,y)
        (-5, -5, -5, 3)  # Negative equality
    ]
    
    passed = 0
    for x, y, z, expected in test_cases:
        dut.x.value = x
        dut.y.value = y
        dut.z.value = z
        await Timer(1, units='ns')
        
        actual = dut.count.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: x={x}, y={y}, z={z} => count={actual}")
        else:
            dut._log.error(f"FAIL: x={x}, y={y}, z={z} => count={actual}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed. {'ALL PASS' if passed == total else 'SOME FAILS'}")