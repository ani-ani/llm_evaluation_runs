import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Precomputed prime exponents for k! (k=0-15, primes [2,3,5,7,11,13])
k_factorial_exponents = [
    [0,0,0,0,0,0],  # 0!
    [0,0,0,0,0,0],  # 1!
    [1,0,0,0,0,0],  # 2!
    [1,1,0,0,0,0],  # 3!
    [3,1,0,0,0,0],  # 4!
    [3,1,1,0,0,0],  # 5!
    [4,2,1,0,0,0],  # 6!
    [4,2,1,1,0,0],  # 7!
    [7,2,1,1,0,0],  # 8!
    [7,4,1,1,0,0],  # 9!
    [8,4,2,1,0,0],  # 10!
    [8,4,2,1,1,0],  # 11!
    [10,5,2,1,1,0], # 12!
    [10,5,2,1,1,1], # 13!
    [11,5,2,1,1,1], # 14!
    [11,6,3,1,1,1]  # 15!
]

def calculate_expected(k_list):
    n = len(k_list)
    prime_exponents = [0]*6
    
    for k_val in k_list:
        if k_val > 15: k_val = 15
        for i in range(6):
            prime_exponents[i] += k_factorial_exponents[k_val][i]
    
    total = sum(prime_exponents)
    min_sum = total
    majority = n
    
    for i in range(6):
        if 2 * prime_exponents[i] > n:
            min_sum -= (2*prime_exponents[i] - n)
    
    return min_sum

@cocotb.test()
async def test_path_sum(dut):
    test_cases = [
        ([2,1,4], 5),  # Original example 1
        ([3,1,4,4], 6),  # Original example 2
        ([3,1,4,1], 6),  # Original example 3
        ([15,13,2], 42),  # Scaled test case
        ([0], 0),  # Edge case
        ([1,5,6], 10)  # Modified case
    ]
    passed = 0
    
    for inputs, expected in test_cases:
        dut.num_fragments.value = len(inputs)
        # Set fragment values (pad with 0s if less than 8)
        for i in range(8):
            if i < len(inputs):
                dut.k[i].value = inputs[i]
            else:
                dut.k[i].value = 0
        await Timer(10, units='ns')
        
        if int(dut.min_sum.value) == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: {inputs} -> {dut.min_sum.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")
