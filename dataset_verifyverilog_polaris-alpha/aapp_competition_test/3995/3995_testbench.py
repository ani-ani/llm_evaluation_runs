import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_min_unique(dut):
    # Test cases adapted to 16-bit width limit
    test_cases = [
        (4, 4, "1111"),
        (5, 3, "01010"),
        (7, 3, "0010010"),
        (1, 1, "1"),
        (16, 2, "0000000100000001"),
        (10, 4, "0001000100")
    ]
    passed = 0
    for n_val, k_val, expected in test_cases:
        dut.n.value = n_val
        dut.k.value = k_val
        await Timer(1, units='ns')
        result = dut.s.value
        # Convert to n-length binary string
        out_str = bin(int(result))[2:].zfill(n_val)
        if out_str == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d k=%d: Got %s, expected %s" % (n_val, k_val, out_str, expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))