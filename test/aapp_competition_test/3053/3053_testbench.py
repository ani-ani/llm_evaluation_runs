import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_palindrome_gen(dut):
    test_cases = [
        # Original scaled cases
        (6, 5, 3, "rarity", False),
        # Scaled case: Original (9,8,1) -> (8,5,1) with new output
        (8, 5, 1, "abcabcda", False),  # Example solution for N=8,K=5,P=1
        (5, 3, 5, "madam", False),
        (2, 2, 2, "", True)  # IMPOSSIBLE
    ]
    passed = 0
    for i, (N, K, P, expected_str, expected_impossible) in enumerate(test_cases):
        dut.N.value = N
        dut.K.value = K
        dut.P.value = P
        await Timer(2, units='ns')
        result = ""
        # Decode output string (N valid characters)
        for j in range(8):
            char_val = dut.out_str.value >> (5*j) & 0x1F
            if j < N:
                result += chr(97 + char_val) if char_val < 26 else '?'
        \
        impossible_flag = dut.impossible.value
        match = (result[:N] == expected_str) if not expected_impossible else (impossible_flag == 1)
        if match:
            passed += 1
        else:
            msg = f"Test {i} failed: N={N},K={K},P={P}
"
            msg += f"Got: '{result[:N]}' (IMPOSSIBLE={impossible_flag})
"
            msg += f"Exp: '{expected_str}' (IMPOSSIBLE={expected_impossible})"
            dut._log.error(msg)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
