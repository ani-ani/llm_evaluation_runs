import cocotb
from cocotb.triggers import Timer
import math

def calc_div_sum(n):
    if n == 1:
        return 0
    total = 1
    i = 2
    while i * i <= n:
        if n % i == 0:
            total += i
            if i != n // i:
                total += n // i
        i += 1
    return total

@cocotb.test()
async def test_div_compare(dut):
    test_cases = [
        (36, 57, False),
        (2, 4, False),
        (23, 47, True),
        (6, 6, True),    # sum=1+2+3=6
        (6, 25, True),   # 1+2+3=6 vs 1+5=6
        (1, 1, True),    # 0==0
        (255, 255, False) # sum(255)=1+3+5+15+17+51+85=177
    ]
    passed = 0
    
    for a, b, expected in test_cases:
        dut.num1.value = a
        dut.num2.value = b
        await Timer(1, units='ns')  # Allow combinational logic
        
        result = int(dut.match_flag.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: ({a},{b})=>{result}")
        else:
            dut._log.error(f"FAIL: ({a},{b})=>{result}, expected {expected}")
            
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")