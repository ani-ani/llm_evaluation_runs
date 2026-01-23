import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

MOD = 10**9 + 7

def to_q16_16(val):
    return int(val * 65536)

def from_q16_16(val):
    # Handle signed values if necessary, but inputs are positive here
    return val / 65536.0

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x_in.value = [0]*8
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_subset_sum_solver(dut):
    """Test the subset sum solver with multiple test cases"""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test cases scaled for N=8
    # Inputs are sorted lists of 8 coordinates
    test_cases = [
        [4, 7, 8, 9, 10, 11, 12, 13],  # Small numbers
        [1, 2, 3, 4, 5, 6, 7, 8],      # Sequential
        [100, 200, 300, 400, 500, 600, 700, 800], # Large gaps
        [1, 1000, 2000, 3000, 4000, 5000, 6000, 7000], # Wide range
        [0, 0, 0, 0, 0, 0, 0, 1]       # Edge case with zeros
    ]
    
    expected_outputs = [
        # Calculated manually or via Python logic for N=8
        # Logic: sum(x[i] * (2^i - 2^(7-i)))
        2552,
        2552,
        255200,
        2552000,
        7
    ]

    total_tests = len(test_cases)
    passed = 0

    for i, (tc, expected) in enumerate(zip(test_cases, expected_outputs)):
        # Prepare inputs in Q16.16
        q_inputs = [to_q16_16(x) for x in tc]
        dut.x_in.value = q_inputs
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        cycles = 0
        while dut.done.value == 0 and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
            
        if cycles >= timeout:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
            
        # Read result
        result_val = int(dut.result.value)
        
        # The result is Q16.16, so we compare the integer representation
        # expected is integer sum, we need to convert to Q16.16 for comparison
        # Wait, the problem asks for sum modulo 10^9+7. The inputs are Q16.16.
        # The operation is: sum(x[i] * coeff) % MOD
        # x[i] is Q16.16. coeff is integer.
        # Result is Q16.16.
        
        # Let's re-verify the expected output logic:
        # If inputs are [4, 7...], Q16.16 is [4*65536, 7*65536...]
        # Result = (4*65536 * c0 + 7*65536 * c1 ...) % MOD
        # Result is Q16.16.
        
        # Python calculation for expected:
        x = tc
        n = 8
        ans = 0
        for idx in range(n):
            ans += x[idx] * (pow(2, idx, MOD) - pow(2, n-1-idx, MOD))
        ans = ans % MOD
        
        # Convert expected integer result to Q16.16 format for comparison
        expected_q16 = ans * 65536
        
        # Handle modulo wrap around in 64-bit result if any, though 10^9 * 65536 fits in 64 bits easily.
        # 10^9 * 65536 ≈ 6.5e13. Max 64-bit signed is ~9e18.
        
        if result_val != expected_q16:
             print(f"Test {i+1} Failed: Inputs {tc}")
             print(f"Expected (Q16.16): {expected_q16}, Got: {result_val}")
             print(f"Diff: {result_val - expected_q16}")
             raise TestFailure(f"Result mismatch for case {i+1}")
        else:
            print(f"Test {i+1} Passed")
            passed += 1
            
        await RisingEdge(dut.clk)

    print(f"
SUMMARY: {passed}/{total_tests} tests passed")
