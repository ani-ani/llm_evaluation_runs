import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_min_product_tuple(dut):
    """Test minimum product calculation for 4 tuples"""
    
    # Test cases from the problem
    test_cases = [
        # Test 1: [(2, 7), (2, 6), (1, 8), (4, 9)] -> 8
        {'x0': 2, 'y0': 7, 'x1': 2, 'y1': 6, 'x2': 1, 'y2': 8, 'x3': 4, 'y3': 9, 'expected': 8},
        # Test 2: [(10,20), (15,2), (5,10)] -> 30 (4th tuple: 0,0)
        {'x0': 10, 'y0': 20, 'x1': 15, 'y1': 2, 'x2': 5, 'y2': 10, 'x3': 0, 'y3': 0, 'expected': 0},
        # Actually test 2 expected is 30, so 0 is wrong. Let's adjust:
        # Original has 3 tuples, we need 4. Let's duplicate or use 0,0
        # Better: use test case 2 with adjusted expectation
        {'x0': 10, 'y0': 20, 'x1': 15, 'y1': 2, 'x2': 5, 'y2': 10, 'x3': 255, 'y3': 255, 'expected': 30},
        # Test 3: [(11,44), (10,15), (20,5), (12, 9)] -> 100
        {'x0': 11, 'y0': 44, 'x1': 10, 'y1': 15, 'x2': 20, 'y2': 5, 'x3': 12, 'y3': 9, 'expected': 100},
        # Edge case: negative-like (all positive, but test zero handling)
        {'x0': 0, 'y0': 100, 'x1': 5, 'y1': 5, 'x2': 10, 'y2': 10, 'x3': 20, 'y3': 20, 'expected': 0},
        # Edge case: all same
        {'x0': 3, 'y0': 3, 'x1': 3, 'y1': 3, 'x2': 3, 'y2': 3, 'x3': 3, 'y3': 3, 'expected': 9},
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut.x0.value = tc['x0']
        dut.y0.value = tc['y0']
        dut.x1.value = tc['x1']
        dut.y1.value = tc['y1']
        dut.x2.value = tc['x2']
        dut.y2.value = tc['y2']
        dut.x3.value = tc['x3']
        dut.y3.value = tc['y3']
        
        await Timer(1, units='ns')
        
        result = int(dut.min_product.value)
        expected = tc['expected']
        
        print(f"Test {i+1}: Input pairs: ({tc['x0']},{tc['y0']}), ({tc['x1']},{tc['y1']}), ({tc['x2']},{tc['y2']}), ({tc['x3']},{tc['y3']})")
        print(f"  Expected: {expected}, Got: {result}")
        
        assert result == expected, f"Test {i+1} failed: expected {expected}, got {result}"
        passed += 1
    
    print(f"
{passed}/{total} tests passed")
