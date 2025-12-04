import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_bitstring(dut):
    test_cases = [
        (3, 6, 0, 1, 0x18, 0),  # '00011' → 00011000 = 0x18
        (1, 0, 2, 3, 0xe0, 0),  # '11100' → 11100000 = 0xe0
        (0, 1, 0, 0, 0x40, 0),  # '01' → 01000000 = 0x40
        (0, 0, 0, 0, 0x00, 0),  # '0' → 00000000 = 0x00
        (5, 0, 0, 5, 0x00, 1)   # Impossible (no n1) 
    ]
    passed = 0
    for (a,b,c,d,exp_str,exp_imp) in test_cases:
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.d.value = d
        await Timer(1, units='ns')
        if dut.impossible.value == exp_imp:
            if exp_imp == 0 and dut.string_out.value == exp_str:
                passed += 1
            elif exp_imp == 1:
                passed += 1
            else:
                dut._log.error("Failed (a=%d,b=%d,c=%d,d=%d): Expected string 0x%02x, got 0x%02x" % (a,b,c,d,exp_str,dut.string_out.value))
        else:
            dut._log.error("Failed (a=%d,b=%d,c=%d,d=%d): Expected imp=%d, got %d" % (a,b,c,d,exp_imp,dut.impossible.value))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))