import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_crazy_town_basic(dut):
    """ Test the line separation logic """
    
    # Helper function to check separation
    def python_implementation(x1, y1, x2, y2, a, b, c):
        val1 = a * x1 + b * y1 + c
        val2 = a * x2 + b * y2 + c
        # Check if signs are different
        return 1 if (val1 < 0) != (val2 < 0) else 0

    # Test cases: (x1, y1, x2, y2, a, b, c)
    test_cases = [
        # Case 1: Line x=0 separates (1,1) and (-1,-1)
        (1, 1, -1, -1, 1, 0, 0),
        # Case 2: Line y=0 separates (1,1) and (-1,-1)
        (1, 1, -1, -1, 0, 1, 0),
        # Case 3: Line x+y=2 does NOT separate (1,1) and (2,2)
        (1, 1, 2, 2, 1, 1, -2),
        # Case 4: Vertical line x=5 separates (4,0) and (6,0)
        (4, 0, 6, 0, 1, 0, -5),
        # Case 5: Large coordinates
        (841746, 527518, 595261, 331297, -946901, 129987, 670374),
    ]

    passed = 0
    total = len(test_cases)

    for i, (x1, y1, x2, y2, a, b, c) in enumerate(test_cases):
        # Expected result
        expected = python_implementation(x1, y1, x2, y2, a, b, c)
        
        # Assign inputs
        dut.x1.value = x1
        dut.y1.value = y1
        dut.x2.value = x2
        dut.y2.value = y2
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Get output
        actual = int(dut.separation.value)
        
        if actual == expected:
            passed += 1
        else:
            print(f"Test {i+1} FAILED: Inputs (x1={x1}, y1={y1}, x2={x2}, y2={y2}, a={a}, b={b}, c={c})")
            print(f"  Expected: {expected}, Got: {actual}")

    print(f"
{passed}/{total} tests passed")
    assert passed == total
