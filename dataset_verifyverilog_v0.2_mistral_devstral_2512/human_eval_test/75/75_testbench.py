import cocotb
from cocotb.triggers import Timer

# Define the valid products list for verification
valid_products = [
    8, 12, 18, 20, 27, 28, 30, 42, 44, 45, 50, 52, 63, 66, 68, 70, 75, 
    76, 78, 92, 98, 99, 102, 105, 110, 114, 116, 124, 125
]

@cocotb.test()
async def test_is_multiply_prime(dut):
    """Test if is_multiply_prime correctly identifies products of 3 primes"""
    
    print("Starting is_multiply_prime tests...")
    
    # Test cases: (input, expected_result)
    test_cases = [
        (5, False),
        (30, True),
        (8, True),
        (10, False),
        (125, True),
        (21, False),  # 3*7 (only 2 primes)
        (18, True),   # 2*3*3
        (60, False),  # 2*2*3*5 (4 primes)
        (0, False),   # edge case
        (127, False), # prime number
        (2, False),   # single prime
        (6, False),   # 2*3 (two primes)
        (27, True),   # 3*3*3
        (45, True),   # 3*3*5
        (105, True),  # 3*5*7
    ]
    
    passed = 0
    for number, expected in test_cases:
        # Apply input
        dut.number.value = number
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.is_product.value)
        expected_int = 1 if expected else 0
        
        if result == expected_int:
            print(f"PASS: Input {number} -> {result} (expected {expected_int})")
            passed += 1
        else:
            print(f"FAIL: Input {number} -> {result} (expected {expected_int})")
    
    print(f"
Summary: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"Only {passed}/{len(test_cases)} tests passed"
