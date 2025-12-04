import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_cone_volume(dut):
    # Test cases (r, h, expected_float)
    test_cases = [
        (5, 12, 314.15926535897927),
        (10, 15, 1570.7963267948965),
        (19, 17, 6426.651371693521),
        (0, 5, 0),          # Edge case: zero radius
        (255, 255, 17312797.766)  # Max input case (adjusted for Q16.16)
    ]
    passed = 0
    
    for r, h, expected_float in test_cases:
        # Convert to Q16.16 fixed-point value
        expected_q16 = int(expected_float * 65536)
        
        # Apply inputs
        dut.r.value = r
        dut.h.value = h
        await Timer(1, units='ns')
        
        # Verify output with 1% tolerance
        actual = dut.volume.value.integer
        delta = abs(actual - expected_q16)
        tolerance = int(0.01 * expected_q16)
        
        if delta <= tolerance:
            passed += 1
            dut._log.info(f"PASS: r={r}, h={h} => {actual} (~{expected_float:.2f})")
        else:
            actual_float = actual / 65536.0
            dut._log.error(f"FAIL: r={r}, h={h} => got {actual_float:.2f}, expected {expected_float:.2f}")
    
    # Special case: zero test
    dut.r.value = 0
    dut.h.value = 10
    await Timer(1, units='ns')
    if dut.volume.value == 0:
        passed += 1
    else:
        dut._log.error(f"FAIL: Zero radius test failed")
    
    dut._log.info(f"{passed}/{len(test_cases)+1} tests passed")