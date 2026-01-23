import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_generate_integers(dut):
    """Test the generate_integers module"""
    
    # Test cases: (a, b, expected_result, expected_distance, description)
    test_cases = [
        (2, 8, 2, 0, "Even input - should return itself"),
        (10, 2, 10, 0, "Even input 10 - should return itself"),
        (132, 2, 98, 1, "Odd input 132 (capped at 99) - should return 98"),
        (17, 89, 16, 1, "Odd input 17 - should return 16"),
        (8, 2, 8, 0, "Even input 8 - should return itself"),
        (3, 0, 2, 1, "Odd input 3 - should return 2"),
        (0, 0, 0, 0, "Zero input (even) - should return 0"),
        (1, 0, 2, 2, "Odd input 1 - should return 2 (distance 2)"),
        (99, 0, 98, 1, "Odd input 99 (max) - should return 98"),
        (98, 0, 98, 0, "Even input 98 - should return itself"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for a, b, expected_result, expected_distance, description in test_cases:
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        result = int(dut.result.value)
        distance = int(dut.distance.value)
        
        # Check results
        if result != expected_result or distance != expected_distance:
            print(f"FAIL: {description}")
            print(f"  Input: a={a}, b={b}")
            print(f"  Expected: result={expected_result}, distance={expected_distance}")
            print(f"  Got: result={result}, distance={distance}")
        else:
            print(f"PASS: {description}")
            passed += 1
    
    print(f"
{passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"{total - passed} test(s) failed")