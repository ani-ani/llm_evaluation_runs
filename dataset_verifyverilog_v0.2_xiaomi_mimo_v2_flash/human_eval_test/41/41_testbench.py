import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_car_race_collision(dut):
    """Test car_race_collision module with multiple inputs"""
    
    # Test cases from original problem
    test_cases = [
        (2, 4),   # 2² = 4
        (3, 9),   # 3² = 9
        (4, 16),  # 4² = 16
        (8, 64),  # 8² = 64
        (10, 100) # 10² = 100
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            passed += 1
            print(f"✓ n={n}: result={result}, expected={expected}")
        else:
            print(f"✗ n={n}: result={result}, expected={expected}")
    
    # Additional edge cases
    edge_cases = [
        (0, 0),      # Zero cars
        (1, 1),      # One car
        (31, 961),   # Max reasonable input (31²=961)
        (32, 1024)   # 32²=1024
    ]
    
    for n, expected in edge_cases:
        dut.n.value = n
        await Timer(10, units='ns')
        result = int(dut.result.value)
        if result == expected:
            passed += 1
            print(f"✓ n={n}: result={result}, expected={expected}")
        else:
            print(f"✗ n={n}: result={result}, expected={expected}")
        total += 1
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
