import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_monotone(dut):
    test_cases = [
        # (n, k, expected_seq)
        (4, 3, 0b001100010011000),  # 1,4,2,3,0
        (5, 1, 0b111111111111111),  # -1 case
        (5, 5, 0b001010011100101)   # 1,2,3,4,5
    ]

    passed = 0
    for (n, k, expected) in test_cases:
        dut.n.value = n
        dut.k.value = k
        await Timer(1, units='ns')
        actual = dut.seq.value
        if actual == expected:
            passed += 1
        else:
            hex_actual = f"{int(actual):015b}"
            hex_expected = f"{int(expected):015b}"
            dut._log.error(f"Failed: n={n}, k={k}
Actual:   {hex_actual}
Expected: {hex_expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
