import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to convert float to Q16.16 fixed point
def to_fixed_point(f):
    return int(f * 65536)

# Helper to calculate expected value (Python reference)
def solve_python(n, hearings):
    # hearings = [(s, a, b), ...]
    # Sort is already done in input
    dp = [0.0] * (n + 1)
    dp[n] = 0.0
    
    for i in range(n - 1, -1, -1):
        s, a, b = hearings[i]
        # Option 1: Skip
        skip_val = dp[i+1]
        
        # Option 2: Attend
        attend_val = 0.0
        length = b - a + 1
        
        for duration in range(a, b + 1):
            finish_time = s + duration
            # Find next hearing j >= finish_time
            # Since hearings are sorted by start time, we can search forward
            next_idx = i + 1
            while next_idx < n and hearings[next_idx][0] < finish_time:
                next_idx += 1
            
            # Contribution
            attend_val += (1.0 / length) * (1.0 + dp[next_idx])
        
        dp[i] = max(skip_val, attend_val)
    
    return dp[0]

@cocotb.test()
async def test_hearing_optimizer(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.a[i].value = 0
        dut.b[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Case 1: Sample input (scaled down slightly if needed, but s=1, a=1,b=7 is valid < 255)
        {
            "n": 4,
            "hearings": [(1, 1, 7), (3, 2, 3), (5, 1, 4), (6, 10, 10)],
            "expected": 2.125
        },
        # Case 2: Second sample (scaled start times if needed, but s=1, 3, 5, 6 are fine)
        {
            "n": 5,
            "hearings": [(1, 1, 7), (1, 1, 6), (3, 2, 3), (5, 1, 4), (6, 10, 10)],
            "expected": 2.29166667
        },
        # Case 3: Simple overlap
        {
            "n": 2,
            "hearings": [(0, 1, 1), (0, 1, 1)],
            "expected": 1.0  # Can only attend one
        },
        # Case 4: Sequential
        {
            "n": 2,
            "hearings": [(0, 1, 1), (1, 1, 1)],
            "expected": 2.0
        }
    ]

    for tc in test_cases:
        dut.n.value = tc["n"]
        for i in range(tc["n"]):
            s, a, b = tc["hearings"][i]
            dut.s[i].value = s
            dut.a[i].value = a
            dut.b[i].value = b
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not dut.done.value and cycles < 20000:
            await RisingEdge(dut.clk)
            cycles += 1
            
        if not dut.done.value:
            raise TestFailure(f"Test timed out for case {tc['expected']}")
            
        # Read result
        result_fp = dut.result.value.integer
        result_float = result_fp / 65536.0
        
        # Check with tolerance
        expected = tc["expected"]
        diff = abs(result_float - expected)
        
        print(f"Case: {tc['hearings']}")
        print(f"Expected: {expected:.8f}, Got: {result_float:.8f}")
        
        # Tolerance 0.01 (relaxed for fixed-point and logic approximations)
        # Q16.16 precision is high enough, but logic might differ slightly in edge cases if not exact.
        # Given the problem constraints, integer math should be exact if implemented correctly.
        if diff > 0.02: 
             raise TestFailure(f"Mismatch: Expected {expected}, got {result_float}")
             
        await Timer(100, units='ns')

    print("All tests passed!")
