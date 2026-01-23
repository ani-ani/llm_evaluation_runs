import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_parabola_directrix(dut):
    """Test parabola directrix calculation with multiple test cases"""
    
    # Test cases: (a, b, c) -> expected directrix
    test_cases = [
        (5, 3, 2, -198),
        (9, 8, 4, -2336),
        (2, 4, 6, -130),
        # Additional edge cases
        (1, 1, 0, -8),      # a=1, b=1, c=0: c - ((1+1)*4*1) = 0 - 8 = -8
        (0, 5, 10, 10),     # a=0: directrix = c - 0 = c
        (1, 0, 0, -4),      # b=0: c - ((0+1)*4*1) = 0 - 4 = -4
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (a, b, c, expected) in enumerate(test_cases):
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.directrix.value)
        
        # Handle signed values in 32-bit output
        if result >= 2**31:
            result = result - 2**32
        
        print(f"Test {i+1}: a={a}, b={b}, c={c}")
        print(f"  Expected: {expected}")
        print(f"  Got:      {result}")
        
        assert result == expected, f"Test {i+1} failed: expected {expected}, got {result}"
        passed += 1
    
    print(f"
Summary: {passed}/{total} tests passed")