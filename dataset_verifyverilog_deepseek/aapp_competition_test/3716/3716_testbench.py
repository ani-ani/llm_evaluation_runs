import cocotb
from cocotb.triggers import Timer
import math

# Software implementation for verification
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def lcm(a, b):
    return a * b // gcd(a, b)

def triple_lcm(i, j, k):
    return lcm(i, lcm(j, k))

def expected_max(n):
    start = max(1, n-7)
    max_val = 0
    for i in range(start, n+1):
        for j in range(start, i+1):
            for k in range(start, j+1):
                current = triple_lcm(i, j, k)
                if current > max_val:
                    max_val = current
    return max_val

@cocotb.test()
async def test_max_lcm(dut):
    test_cases = [
        (9, 504),  # Original test case within range
        (7, 210),  
        (1, 1),    
        (3, 6),    
        (4, 12),   
        (8, 336),  # New test case
        (10, 630), # Checks upper range limit
        (6, 60)    # Verify range from 6-7 down to max(1,6-7)=1
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.max_lcm.value
        if result == expected:
            passed += 1
        else:
            calculated = expected_max(n_val)
            dut._log.error(f"FAIL: n={n_val} Result={result} Expected={expected} Calculated={calculated}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")