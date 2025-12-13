import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_will_it_fly(dut):
    test_cases = [
        # (q_list, w, expected)
        ([3, 2, 3], 9, True),
        ([1, 2], 5, False),
        ([3], 5, True),
        ([3, 2, 3], 1, False),
        ([1, 2, 3], 6, False),
        ([5], 5, True)
    ]
    
    passed = 0
    for arr, w_val, expected in test_cases:
        # Flatten array to 64-bit input (pad with zeros)
        flat = 0
        for i, val in enumerate(arr):
            flat |= val << (i * 8)
        
        dut.q_flat.value = flat
        dut.length.value = len(arr)
        dut.w.value = w_val
        await Timer(1, units='ns')
        
        actual = bool(dut.will_fly.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {arr}, {w_val} -> {expected}")
        else:
            dut._log.error(f"FAIL: {arr}, {w_val} -> {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")