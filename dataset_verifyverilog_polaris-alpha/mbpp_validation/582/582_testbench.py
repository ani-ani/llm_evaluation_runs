import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_dict_empty(dut):
    # Test cases: (entries list, expected_empty)
    test_cases = [
        # Test 1: Fully empty
        ([0b0_00000000]*8, True),
        # Test 2: Single entry valid (Test1 original)
        ([0b1_00001010] + [0b0_00000000]*7, False),
        # Test 3: Last entry valid (Test2 original)
        ([0b0_00000000]*7 + [0b1_00001011], False),
        # Test 4: All valid
        ([0b1_11111111]*8, False),
        # Test 5: Two entries valid
        ([0b1_00000001, 0b1_00000010] + [0b0_00000000]*6, False),
    ]
    
    passed = 0
    for entries, expected in test_cases:
        # Assign inputs
        for i, val in enumerate(entries):
            dut.entries[i].value = val
        
        await Timer(1, units='ns')
        
        if dut.empty_flag.value == expected:
            passed += 1
            dut._log.info(f"PASS: entries={entries} → empty={expected}")
        else:
            dut._log.error(f"FAIL: entries={entries} → got {dut.empty_flag.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")