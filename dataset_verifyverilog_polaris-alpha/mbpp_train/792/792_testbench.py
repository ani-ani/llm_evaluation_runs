import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_count_lists(dut):
    test_cases = [
        (0b00001111, 4),  # Test 1: 4 sublists
        (0b00000111, 3),  # Test 2: 3 sublists
        (0b00000011, 2)   # Test 3: 2 sublists
    ]
    
    passed = 0
    for mask, expected in test_cases:
        dut.sublist_mask.value = mask
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: mask={bin(mask)} count={result}")
        else:
            dut._log.error(f"FAIL: mask={bin(mask)} got {result}, expected {expected}")
    
    # Additional edge cases
    edge_cases = [
        (0b00000000, 0),  # Empty input
        (0b11111111, 8),  # Full input
        (0b10101010, 4)   # Alternating bits
    ]
    
    for mask, expected in edge_cases:
        dut.sublist_mask.value = mask
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: mask={bin(mask)} count={result}")
        else:
            dut._log.error(f"FAIL: mask={bin(mask)} got {result}, expected {expected}")
    
    total = len(test_cases) + len(edge_cases)
    dut._log.info(f"{passed}/{total} tests passed")