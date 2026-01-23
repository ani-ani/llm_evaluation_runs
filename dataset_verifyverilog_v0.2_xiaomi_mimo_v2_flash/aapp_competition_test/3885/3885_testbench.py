import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_min_ticket_cost(dut):
    """Test minimum ticket cost calculation for various inputs"""
    
    # Test cases: (n, expected_cost)
    test_cases = [
        (1, 0),
        (2, 0),
        (3, 1),
        (4, 1),
        (10, 4),
        (43670, 21834),
        (4217, 2108),
        (17879, 8939),
        (100000, 49999),
        (99999, 49999),
        (99998, 49998),
        (99997, 49998),
        (99996, 49997),
        (100000, 49999)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.cost.value)
        
        if result == expected:
            passed += 1
        else:
            print(f"FAIL: n={n}, expected={expected}, got={result}")
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
