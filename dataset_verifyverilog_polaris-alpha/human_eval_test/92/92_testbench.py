import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_any_int(dut):
    """Test for integer sum condition checker"""
    
    # Valid integer test cases (adapted from original)
    test_cases = [
        # (x, y, z, expected)
        (2,  3,  1, 1),   # 2+1=3
        (4,  2,  2, 1),   # 2+2=4
        (-4, 6,  2, 1),   # -4+6=2
        (2,  1,  1, 1),   # 1+1=2
        (3,  4,  7, 1),   # 3+4=7
        (3,  2,  2, 0),   # No sum match
        (2,  6,  2, 0),   # No sum match
        # Edge cases
        (127, 127, -254, 1),  # Max positive check
        (-128, -128, 0, 0)    # Min negative (no match)
    ]
    
    passed = 0
    for idx, (x, y, z, expected) in enumerate(test_cases):
        dut.x.value = x
        dut.y.value = y
        dut.z.value = z
        await Timer(1, units='ns')  # Allow combinational logic
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"Test {idx}: PASS ({x}, {y}, {z}) => {expected}")
        else:
            dut._log.error(f"Test {idx}: FAIL ({x}, {y}, {z}) => {dut.result.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"