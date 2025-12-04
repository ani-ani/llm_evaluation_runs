import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_unique_checker(dut):
    # Test cases adapted for 4-element array
    test_cases = [
        ([1,2,3,4], True),   # All unique (Original Test 1 extended)
        ([1,2,1,2], False),  # Duplicates (Original Test 2)
        ([1,2,3,5], True),   # All unique (Original Test 3 extended)
        ([0,0,0,0], False),  # All duplicates (Added edge case)
        ([15,1,2,3], True)   # Max value test (Added edge case)
    ]
    
    passed = 0
    
    for i, (data, expected) in enumerate(test_cases):
        # Set input values
        for idx in range(4):
            dut.data[idx].value = data[idx]
        
        await Timer(1, units='ns')
        
        if dut.is_unique.value == expected:
            passed += 1
            dut._log.info(f"PASS {i}: {'Unique' if expected else 'Duplicate'} ({data})")
        else:
            dut._log.error(f"FAIL {i}: Data {data} → {dut.is_unique.value}, expected {expected}")
    
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)