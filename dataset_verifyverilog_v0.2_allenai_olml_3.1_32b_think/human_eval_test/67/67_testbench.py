import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_fruit_distribution(dut):
    """Test fruit distribution calculation"""
    
    # Helper to convert integer to 8-bit value (simulating the fixed-width input)
    # In a real scenario, these would be raw bytes, but here we pass integer values directly
    
    test_cases = [
        # (apples, oranges, total, expected_mangoes)
        (5, 6, 19, 8),
        (5, 6, 21, 10),
        (0, 1, 3, 2),
        (1, 0, 3, 2),
        (2, 3, 100, 95),
        (2, 3, 5, 0),
        (1, 100, 120, 19),
        (255, 255, 255, 0),  # Edge case: saturated to 0
        (0, 0, 0, 0),        # Edge case: all zeros
    ]
    
    print("Running fruit_distribution tests...")
    passed = 0
    total = len(test_cases)
    
    for apples, oranges, total_fruits, expected in test_cases:
        # Set inputs
        dut.apples_str.value = apples
        dut.oranges_str.value = oranges
        dut.total_fruits.value = total_fruits
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.mangoes.value)
        
        # Assert
        if result == expected:
            passed += 1
        else:
            print(f"FAIL: apples={apples}, oranges={oranges}, total={total_fruits} -> got {result}, expected {expected}")
            assert False, f"Expected {expected}, got {result}"
    
    print(f"{passed}/{total} tests passed")