import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_set_leftmost_unset_bit(dut):
    test_cases = [
        (10, 14),  # 1010 → 1110
        (12, 14),  # 1100 → 1110
        (15, 15),  # 1111 remains
        (0,  1),   # 0000 → 0001
        (9,  13)   # 1001 → 1101
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')  # Allow combinational settling
        
        # Convert to integer for comparison
        result_val = dut.result.value.integer
        
        if result_val == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} (0b{BinaryValue(value=n_val, bit_length=4, bigEndian=False).binstr}) → result={result_val}")
        else:
            dut._log.error(f"FAIL: n={n_val} (0b{BinaryValue(value=n_val, bit_length=4, bigEndian=False).binstr}) → {result_val} (expected {expected} = 0b{BinaryValue(value=expected, bit_length=4, bigEndian=False).binstr})")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")