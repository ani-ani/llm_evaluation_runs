import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

MOD = 1000000007

# Precompute expected results for validation
def calculate_expected(N, caa, cab, cba, cbb):
    if N <= 3:
        return 1
    # Map 'A'->0, 'B'->1
    c = [0 if x == 'A' else 1 for x in [caa, cab, cba, cbb]]
    
    # Check specific conditions based on Python solution analysis
    # Condition 1: Constant 1
    if (c[1] == 0 and c[0] == 0) or (c[1] == 1 and c[3] == 1):
        return 1
        
    # Condition 2: Power of 2 or Fibonacci
    # We need to check the relationship between c[1] (AB) and c[2] (BA)
    # However, the Python code flips logic based on c[1].
    # Let's use the simplified logic from the prompt:
    if c[1] != c[2]:
        # Power of 2 case
        return pow(2, N-3, MOD)
    else:
        # Fibonacci case (additive)
        a, b = 1, 1
        for _ in range(N-3):
            a, b = b, (a + b) % MOD
        return a

@cocotb.test()
async def test_string_generator(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.c_AA.value = 0
    dut.c_AB.value = 0
    dut.c_BA.value = 0
    dut.c_BB.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    test_cases = [
        # (N, c_AA, c_AB, c_BA, c_BB) - expected output description
        (4, 'A', 'B', 'B', 'A'),    # Example case
        (10, 'B', 'B', 'B', 'B'),   # Should be 1
        (5, 'A', 'B', 'A', 'A'),    # Should be 2^2 = 4
        (6, 'A', 'B', 'B', 'A'),    # Fibonacci-like
        (128, 'B', 'A', 'A', 'A'),  # Fibonacci large
        (8, 'B', 'A', 'B', 'A'),    # Power of 2
    ]
    
    passed = 0
    total = len(test_cases)
    
    for N, caa, cab, cba, cbb in test_cases:
        # Prepare inputs
        dut.N.value = N
        dut.c_AA.value = ord(caa) - ord('A')
        dut.c_AB.value = ord(cab) - ord('A')
        dut.c_BA.value = ord(cba) - ord('A')
        dut.c_BB.value = ord(cbb) - ord('A')
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 200 # Cycles
        while dut.done.value == 0 and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
            
        if timeout == 0:
            print(f"Test failed for N={N}: Timeout")
            continue
            
        # Check result
        expected = calculate_expected(N, caa, cab, cba, cbb)
        actual = int(dut.result.value)
        
        print(f"N={N} Rules={caa}{cab}{cba}{cbb} Expected={expected} Actual={actual}")
        
        if actual == expected:
            passed += 1
        else:
            print(f"  MISMATCH!")
            
    print(f"Tests passed: {passed}/{total}")
    assert passed == total
