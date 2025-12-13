import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_phone_number_counter(dut):
    def str_to_bits(s):
        bits = 0
        for c in s.ljust(32, '0'):
            bits = (bits << 4) | int(c)
        return bits
    
    test_cases = [
        (11, '00000000008', 1),
        (22, '0011223344556677889988', 2),
        (11, '31415926535', 0),
        (32, '88888888888888888888888888888888', 2),
        (10, '8888888888', 0),
        (22, '88888888888888888888', 2),
        (8, '12345678', 0),
        (32, '88888888888888888888888888888888', 2)
    ]
    passed = 0
    for n_val, s_str, expected in test_cases:
        dut.n.value = n_val
        dut.s.value = str_to_bits(s_str)
        await Timer(1, units='ns')
        if dut.count.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d s='%s' =%%d expected=%%d" 
                          %% (n_val, s_str, dut.count.value, expected))
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")