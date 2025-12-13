import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_rotator(dut):
    """Test list rotation"""

    test_cases = [
        # Format: (input_list, m, expected_output)
        ([1,2,3,4,5,6,7,8], 3, [6,7,8,1,2,3,4,5]),
        ([1,2,3,4,5,6,7,8], 2, [7,8,1,2,3,4,5,6]),
        ([1,2,3,4,5,6,7,8], 5, [4,5,6,7,8,1,2,3]),
        ([8,7,6,5,4,3,2,1], 7, [7,6,5,4,3,2,1,8]),  # Edge case: max rotation
        ([8,7,6,5,4,3,2,1], 0, [8,7,6,5,4,3,2,1])  # Edge case: no rotation
    ]

    passed = 0
    for input_list, m_val, expected in test_cases:
        # Assign inputs
        for i in range(8):
            dut.data_in[i].value = input_list[i]
        dut.m.value = m_val

        # Wait for combinational logic
        await Timer(1, units='ns')

        # Get outputs
        out_list = [dut.data_out[i].value.integer for i in range(8)]

        # Check results
        if out_list == expected:
            passed += 1
            dut._log.info(f"PASS: m={m_val} {input_list} → {out_list}")
        else:
            dut._log.error(f"FAIL: m={m_val}
Input: {input_list}
Got: {out_list}
Expected: {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total