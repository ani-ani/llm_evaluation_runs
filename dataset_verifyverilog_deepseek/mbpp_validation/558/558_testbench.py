import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_digit_distance(dut):
    test_cases = [
        (1, 2, 1),     # |1-2|=1 → sum=1
        (23, 56, 6),   # |23-56|=33 → 3+3=6
        (123, 256, 7), # |123-256|=133 → 1+3+3=7
        (100, 99, 1),  # |100-99|=1 → sum=1 ('01' but leading 0 ignored)
        (9999, 0, 36), # |9999-0|=9999 → 9*4=36
        (65535, 65535, 0) # max diff test
    ]
    
    passed = 0
    for n1, n2, expected in test_cases:
        dut.n1.value = n1
        dut.n2.value = n2
        await Timer(1, units='ns')
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {n1},{n2} -> {dut.result.value}")
        else:
            dut._log.error(f"FAIL: {n1},{n2} -> {dut.result.value}, expected {expected}")
    
    # Random test case
    a = random.randint(0, 50000)
    b = random.randint(0, 50000)
    diff = abs(a - b)
    expected = sum(int(d) for d in str(diff))
    dut.n1.value = a
    dut.n2.value = b
    await Timer(1, units='ns')
    if dut.result.value == expected:
        passed += 1
        dut._log.info(f"PASS: random {a},{b} -> {dut.result.value}")
    else:
        dut._log.error(f"FAIL: random {a},{b} -> {dut.result.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)+1} tests passed")