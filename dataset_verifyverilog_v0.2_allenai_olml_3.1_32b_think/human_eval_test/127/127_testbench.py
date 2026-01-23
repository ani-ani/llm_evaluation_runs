import cocotb
from cocotb.triggers import Timer

# Prime numbers within range 0-63
PRIMES = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61}

def calculate_expected(start1, end1, start2, end2):
    """Calculate expected result in Python"""
    # Intersection start = max(start1, start2)
    intersect_start = max(start1, start2)
    # Intersection end = min(end1, end2)
    intersect_end = min(end1, end2)
    
    # Check if they intersect
    if intersect_start > intersect_end:
        return 0
    
    # Calculate length
    length = intersect_end - intersect_start
    
    # Length must be > 0 and prime
    if length > 0 and length in PRIMES:
        return 1
    else:
        return 0

@cocotb.test()
async def test_interval_intersection_prime(dut):
    """Test interval intersection prime detection"""
    
    # Test cases: (start1, end1, start2, end2, expected_result, description)
    test_cases = [
        # Original test cases adapted to expected output
        (1, 2, 2, 3, 0, "intersection(1,2),(2,3) length=0 -> NO"),  # was NO
        (-1, 1, 0, 4, 0, "intersection(-1,1),(0,4) length=1 -> NO"),  # length=1, not prime
        (-3, -1, -5, 5, 1, "intersection(-3,-1),(-5,5) length=2 -> YES"),  # length=2, prime
        (-2, 2, -4, 0, 1, "intersection(-2,2),(-4,0) length=2 -> YES"),  # length=2, prime
        
        # Edge cases
        (-11, 2, -1, -1, 0, "intersection(-11,2),(-1,-1) length=0 -> NO"),  # no intersection
        (1, 2, 3, 5, 0, "intersection(1,2),(3,5) length=0 -> NO"),  # no intersection
        (1, 2, 1, 2, 0, "intersection(1,2),(1,2) length=1 -> NO"),  # length=1, not prime
        (-2, -2, -3, -2, 0, "intersection(-2,-2),(-3,-2) length=0 -> NO"),  # point intersection
        
        # Additional test cases for primes
        (0, 3, 2, 5, 1, "intersection(0,3),(2,5) length=2 -> YES"),  # length=2, prime
        (0, 4, 2, 5, 1, "intersection(0,4),(2,5) length=2 -> YES"),  # length=2, prime
        (0, 5, 2, 5, 1, "intersection(0,5),(2,5) length=3 -> YES"),  # length=3, prime
        (0, 6, 2, 5, 1, "intersection(0,6),(2,5) length=3 -> YES"),  # length=3, prime
        (0, 8, 2, 5, 1, "intersection(0,8),(2,5) length=3 -> YES"),  # length=3, prime
        
        # Non-prime lengths
        (0, 4, 0, 4, 0, "intersection(0,4),(0,4) length=4 -> NO"),  # length=4, not prime
        (0, 6, 0, 6, 0, "intersection(0,6),(0,6) length=6 -> NO"),  # length=6, not prime
        (0, 9, 0, 9, 0, "intersection(0,9),(0,9) length=9 -> NO"),  # length=9, not prime
        
        # Primes > 2
        (0, 6, 1, 5, 1, "intersection(0,6),(1,5) length=4 -> NO"),  # length=4
        (0, 8, 2, 7, 1, "intersection(0,8),(2,7) length=5 -> YES"),  # length=5, prime
        (0, 10, 2, 7, 1, "intersection(0,10),(2,7) length=5 -> YES"),  # length=5, prime
        (0, 12, 2, 9, 1, "intersection(0,12),(2,9) length=7 -> YES"),  # length=7, prime
        (0, 14, 2, 11, 1, "intersection(0,14),(2,11) length=9 -> NO"),  # length=9, not prime
        (0, 18, 2, 15, 1, "intersection(0,18),(2,15) length=13 -> YES"),  # length=13, prime
        (0, 22, 2, 19, 1, "intersection(0,22),(2,19) length=17 -> YES"),  # length=17, prime
        
        # Boundary and negative tests
        (-10, 10, -5, 5, 1, "intersection(-10,10),(-5,5) length=10 -> NO"),  # length=10
        (-10, 10, -3, 3, 1, "intersection(-10,10),(-3,3) length=6 -> NO"),  # length=6
        (-10, 10, -2, 2, 1, "intersection(-10,10),(-2,2) length=4 -> NO"),  # length=4
        (-10, 10, -1, 1, 1, "intersection(-10,10),(-1,1) length=2 -> YES"),  # length=2, prime
        
        # Single point intervals
        (5, 5, 5, 5, 0, "intersection(5,5),(5,5) length=0 -> NO"),  # point intersection
        (5, 5, 4, 6, 0, "intersection(5,5),(4,6) length=0 -> NO"),  # point in range
    ]
    
    passed = 0
    failed = 0
    
    for i, (s1, e1, s2, e2, expected, desc) in enumerate(test_cases):
        # Set inputs
        dut.start1.value = s1
        dut.end1.value = e1
        dut.start2.value = s2
        dut.end2.value = e2
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.is_prime.value)
        
        # Verify
        python_result = calculate_expected(s1, e1, s2, e2)
        
        if result == expected and result == python_result:
            print(f"Test {i+1:2d}: PASS - {desc}")
            passed += 1
        else:
            print(f"Test {i+1:2d}: FAIL - {desc}")
            print(f"         Expected: {expected}, Got: {result}, Python: {python_result}")
            failed += 1
    
    print(f"
Results: {passed}/{len(test_cases)} tests passed")
    assert failed == 0, f"{failed} tests failed"
