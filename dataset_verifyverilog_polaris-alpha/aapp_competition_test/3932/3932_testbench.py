import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_tree_validator(dut):
    test_cases = [
        # (n, c_array, expected)
        (4, [1,1,1,4] + [0]*20, 1),  # YES
        (5, [1,1,5,2,1] + [0]*19, 0),  # NO (has 2)
        (1, [1] + [0]*23, 1),  # YES
        (16, [1]*12 + [16,1,1,1] + [0]*8, 1),  # YES
        (2, [1,2] + [0]*22, 0)   # NO (has 2 and root ≠2)
    ]
    passed = 0
    for i, (n_val, c_vals, expected) in enumerate(test_cases):
        dut.n.value = n_val
        for j in range(24):
            dut.c[j].value = c_vals[j]
        await Timer(10, units='ns')
        if int(dut.valid.value) != expected:
            raise TestFailure(f"Test {i+1} failed: n={n_val}, c={c_vals[:n_val]} expected {expected} got {dut.valid.value}")
        else:
            passed += 1
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")