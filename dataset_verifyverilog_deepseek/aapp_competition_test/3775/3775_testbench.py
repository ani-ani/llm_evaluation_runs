import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryRepresentation, BinaryValue

@cocotb.test()
async def test_participant(dut):
    # Test cases: (n, m, a_pairs_hex_str, b_pairs_hex_str, expected_result)
    test_cases = [
        # Example 1 (output 1)
        (2, 2, "1200340000000000", "1500340000000000", 1),
        # Example 2 (output 0)
        (2, 2, "1200340000000000", "1500640000000000", 0),
        # Example 3 (output -1)
        (3, 2, "1200450000000000", "1200130000000000", 15),
        # Edge case: single pair exact match (output -1)
        (1, 1, "3400000000000000", "3400000000000000", 15),
        # Edge case: all pairs unique number (output 0)
        (2, 2, "1200560000000000", "1200780000000000", 0)
    ]

    passed = 0
    for idx, (n, m, a_hex, b_hex, expected) in enumerate(test_cases):
        dut.n.value = n
        dut.m.value = m
        dut.a_pairs.value = BinaryValue(a_hex, n_bits=64, bigEndian=False)
        dut.b_pairs.value = BinaryValue(b_hex, n_bits=64, bigEndian=False)
        await Timer(1, units='ns')
        actual = dut.result.value
        if actual == expected:
            passed += 1
            dut._log.info(f"Test {idx} passed")
        else:
            dut._log.error(f"Test {idx} failed: Got {actual}, expected {expected}
                Input: n={n}, m={m}, a_pairs={a_hex}, b_pairs={b_hex}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
