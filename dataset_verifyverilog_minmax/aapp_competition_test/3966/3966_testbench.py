import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_max_score(dut):
    # Test cases (n, array, expected_score)
    test_cases = [
        (3, [3,1,5], 26),          # Original example
        (1, [10], 10),             # Single element case
        (2, [1,2], 6),             # From inputs
        (2, [2,3], 10),            # 2*2 + 3*2 = 10 (but n=2 needs coefficient n only for last element)
        (2, [1,1], 4),             # 1*2 + 1*2 = 4? Wait - implementation gives 1*2 + 1*2 -1 = 3?? Revise formula... Wait on problem description
        (4, [2,2,5,5], 54),       # Computation: 2*2 + 2*3 + 5*4 + 5*4 = 4+6+20+20=50? But last term should use (n=4) coefficient?
        # Correct formula based on samples:
        # - For n=3: 3*(2) + 1*(3) +5*(3) =6+3+15=24? Wait problem says 26
        # Actually: score += sum at each group step.
        # Better to recalc to match Python solutions:
        # score = total_sum + Σ arr[i]*(i+1) for sorted array, then subtract last element
        # Python solution: sum(i*x for i,x in enumerate(t,2)) - t[-1]
        # Let's recalc test values accordingly:
        # test4 (4,[2,2,5,5]): sorted => [2,2,5,5]
        # i=0: 2*(2) + 2*(3) + 5*(4) +5*(5) = 4+6+20+25=55 then -5 → 50
        # But according to problem logic, the total should be computed based on game steps. After checking:
        # For n=4, following optimal split:
        # Initial group: sum=2+2+5+5=14 (added to score)
        # Split into [5,5] and [2,2] → sum(5+5)=10 and sum(2+2)=4 added → total so far 14+10+4=28
        # Then split [5,5] into [5],[5] → each adds 5 → +5+5=10 → total 38
        # Split [2,2] into [2],[2] → each adds 2→ +2+2=4 → total 42?
        # However, the formula from Python solutions gives:
        # sum(enumerate([2,2,5,5],2)) = 2*2 + 2*3 + 5*4 +5*5 =4+6+20+25=55 -5 =50
        # So adjust test cases to match formula
        (4, [2,2,5,5], 50),
        (2, [1,1], 1*2 +1*2 -1 = 3),  # Formula: sum(i*x for i,x in enumerate([1,1],2))→ 1*2 +1*3=5 -1(last)=4? Python code says1+2=3? Wait confusion
        # To prevent mistakes, base test cases strictly on Python sample outputs:
        (2, [2,3], 3+5=8 → but sample input2 gives 10? Wait sample input2 is n=2, arr=[2,3]: output is 10 (from inputs list)
    ]
    passed = 0
    for n_val, arr_vals, expected in test_cases:
        dut.n.value = n_val
        # Pad with zeros for unused array elements
        padded_arr = arr_vals + [0]*(8 - len(arr_vals))
        for i in range(8):
            dut.arr[i].value = padded_arr[i]
        await Timer(1, units='ns') # Combinational delay
        result = dut.score.value
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: n={n_val}, arr={arr_vals} → Got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
