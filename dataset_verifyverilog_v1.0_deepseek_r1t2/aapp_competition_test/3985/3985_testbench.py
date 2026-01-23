import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to compute exponent of 2 in a number
def exponent_of_2(x):
    if x == 0:
        return 0
    count = 0
    while x % 2 == 0:
        count += 1
        x //= 2
    return count

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_operations(dut):
    # Test cases from the problem
    test_cases = [
        ([8, 3, 8], 0),
        ([8, 12, 8], 2),
        ([35, 33, 46, 58, 7, 61], 0),
        ([262144, 262144, 64, 64, 16, 134217728, 32, 512, 32, 8192], 38),
        ([67108864, 8, 2, 131072, 268435456, 256, 16384, 128, 8, 128], 31),
        ([512, 64, 536870912, 256, 1, 262144, 8, 2097152, 8192, 524288, 32, 2, 16, 16777216, 524288, 64, 268435456, 256, 67108864, 131072], 65),
        ([512, 524288, 268435456, 2048, 16384, 8192, 524288, 16777216, 128, 536870912, 256, 1, 32768, 2097152, 131072, 268435456, 262144, 134217728, 8388608, 16], 99),
        ([4, 65536, 2097152, 512, 16777216, 262144, 4096, 4096, 64, 32, 268435456, 2, 2048, 128, 512, 1048576, 524288, 1024, 512, 536870912], 71),
        ([2097152, 2048, 1024, 134217728, 536870912, 2097152, 32768, 2, 16777216, 67108864, 4194304, 4194304, 512, 16, 1048576, 8, 16384, 131072, 8388608, 8192, 2097152, 4], 28),
        ([2048, 536870912, 64, 65536, 524288, 2048, 4194304, 131072, 8, 128], 61),
        ([1020407, 1020407], 1),
        ([1020407, 1020407, 1020407, 1020407, 1020407, 1020407, 1020407, 1020407], 4),
        ([9999991, 9999991], 1),
        ([19961993, 19961993], 1),
        ([1, 2, 2, 2, 2], 2),
        ([10, 10], 2),
        ([1, 1000003, 1000003, 1000003, 1000003], 2),
        ([12, 7, 8, 12, 7, 8], 5),
        ([2, 2, 2, 2], 2),
        ([12, 3, 4, 12, 8, 8], 5)
    ]
    
    passed = 0
    failed = 0
    
    for i, (array, expected) in enumerate(test_cases):
        # Compute exponents for first 8 elements, pad with zeros if needed
        exponents = [exponent_of_2(x) for x in array[:8]]
        while len(exponents) < 8:
            exponents.append(0)
        
        # Assign to DUT
        dut.e0.value = exponents[0]
        dut.e1.value = exponents[1]
        dut.e2.value = exponents[2]
        dut.e3.value = exponents[3]
        dut.e4.value = exponents[4]
        dut.e5.value = exponents[5]
        dut.e6.value = exponents[6]
        dut.e7.value = exponents[7]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"Test {i+1} failed: expected {expected}, got {result} for array {array}")
            failed += 1
        else:
            cocotb.log.info(f"Test {i+1} passed: {result}")
            passed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")