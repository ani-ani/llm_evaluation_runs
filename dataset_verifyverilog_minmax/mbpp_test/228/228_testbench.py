import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_unset_bits(dut):
    test_cases = [
        # (n, l, r, expected)
        (4, 1, 2, 1),     # binary 00000100, bits [1:2] = 00
        (17, 2, 4, 1),    # binary 00010001, bits [2:4] = 000
        (39, 4, 6, 0),     # binary 00100111, bits [4:6] = 001
        (15, 1, 4, 0),     # binary 00001111, bits [1:4] = 111
        (8, 4, 4, 0),      # binary 00001000, bit 4 = 1
        (0, 1, 8, 1),      # all zero
        (255, 5, 8, 0)     # all ones
    ]
    
    passed = 0
    
    for (n_val, l_val, r_val, expected) in test_cases:
        dut.n.value = n_val
        dut.l.value = l_val
        dut.r.value = r_val
        await Timer(1, units='ns')
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: n=0x{n_val:02x}, l={l_val}, r={r_val} => {expected}")
        else:
            dut._log.error(f"FAIL: n=0x{n_val:02x}, l={l_val}, r={r_val} => {dut.result.value}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"Test summary: {passed}/{total} tests passed")