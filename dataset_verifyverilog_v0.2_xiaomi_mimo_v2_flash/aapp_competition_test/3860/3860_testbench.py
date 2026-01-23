import cocotb
from cocotb.triggers import Timer
import random

# Helper function to compute expected result
def compute_expected(b, g, n):
    count = 0
    for k in range(n + 1):
        if k <= b and (n - k) <= g:
            count += 1
    return count

@cocotb.test()
async def test_badge_decks(dut):
    """Test badge_decks module against Python reference"""
    
    # Test range: n up to 63, b/g up to 63
    test_cases = []
    
    # Add specific edge cases
    test_cases.extend([
        (5, 6, 3),   # Example 1
        (5, 3, 5),   # Example 2
        (1, 200, 33),
        (300, 300, 600), # But scaled: we pass 63 for n if >63
    ])
    
    # Generate random test cases
    for _ in range(50):
        b = random.randint(0, 63)
        g = random.randint(0, 63)
        n = random.randint(0, 63)
        test_cases.append((b, g, n))
    
    passed = 0
    total = len(test_cases)
    
    for b, g, n in test_cases:
        # Scale down if necessary (though random generation already respects bounds)
        # If constraints were original, we'd clamp. Here inputs are already scaled.
        
        # Set inputs
        dut.b.value = b
        dut.g.value = g
        dut.n.value = n
        
        # Combinational logic, allow some propagation time
        await Timer(10, units='ns')
        
        # Get result
        try:
            result = int(dut.count.value)
            expected = compute_expected(b, g, n)
            
            if result == expected:
                passed += 1
            else:
                print(f"FAIL: b={b}, g={g}, n={n}. Expected {expected}, got {result}")
        except Exception as e:
            print(f"Error on b={b}, g={g}, n={n}: {e}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Some tests failed ({passed}/{total})"
