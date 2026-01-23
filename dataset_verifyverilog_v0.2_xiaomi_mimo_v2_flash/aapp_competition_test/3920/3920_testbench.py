import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_hexagon_triangles(dut):
    """Test hexagon triangle counting module"""
    
    test_cases = [
        # (a1, a2, a3, a4, a5, a6, expected)
        # Original test cases scaled to fit 8-bit inputs (0-255)
        # Original: 1 1 1 1 1 1 -> 6
        (1, 1, 1, 1, 1, 1, 6),
        # Original: 1 2 1 2 1 2 -> 13
        (1, 2, 1, 2, 1, 2, 13),
        # Original: 2 4 5 3 3 6 -> 83
        (2, 4, 5, 3, 3, 6, 83),
        # Original: 7 5 4 8 4 5 -> 175
        (7, 5, 4, 8, 4, 5, 175),
        # Original: 3 2 1 4 1 2 -> 25
        (3, 2, 1, 4, 1, 2, 25),
        # Edge case: small values, result 0 (if valid geometry)
        # Note: Original problem guarantees valid geometry, so we stick to valid cases
        # Max case scaled down (1000 -> 200 for 8-bit)
        (200, 200, 200, 200, 200, 200, 60000),
        # Another random case
        (10, 20, 15, 10, 5, 25, 925),
        # Zero case (if allowed, though problem says >= 1)
        (0, 0, 0, 0, 0, 0, 0)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (a1, a2, a3, a4, a5, a6, expected) in enumerate(test_cases):
        # Set inputs
        dut.a1.value = a1
        dut.a2.value = a2
        dut.a3.value = a3
        dut.a4.value = a4
        dut.a5.value = a5
        dut.a6.value = a6
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.count.value)
        
        if result == expected:
            passed += 1
            print(f"Test {i+1}: PASS (a1={a1}, a2={a2}, a3={a3}, a4={a4}, a5={a5}, a6={a6}) -> {result}")
        else:
            print(f"Test {i+1}: FAIL (a1={a1}, a2={a2}, a3={a3}, a4={a4}, a5={a5}, a6={a6}) -> Expected {expected}, Got {result}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
