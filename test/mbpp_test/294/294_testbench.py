import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_max_valid(dut):
    test_cases = [
        # Original Test 1 (padded to 8 elements)
        {'data': [0,3,2,4,5,0,0,0], 'mask': 0b01111000, 'expected': 5},
        # Original Test 2 (padded)
        {'data': [0,15,20,25,0,0,0,0], 'mask': 0b01111000, 'expected': 25},
        # Original Test 3 (padded)
        {'data': [0,30,20,40,50,0,0,0], 'mask': 0b11111000, 'expected': 50},
        # Edge Case: All invalid
        {'data': [10,20,30,40,50,60,70,80], 'mask': 0b00000000, 'expected': 0},
        # Single Valid
        {'data': [0,0,100,0,0,0,0,0], 'mask': 0b00100000, 'expected': 100}
    ]

    passed = 0
    for case in test_cases:
        # Assign inputs
        for i in range(8):
            dut.data[i].value = case['data'][i]
        dut.valid_mask.value = case['mask']
        
        await Timer(1, 'ns')  # Combinational settling
        
        result = dut.max_val.value.integer
        if result == case['expected']:
            passed += 1
            dut._log.info(f"PASS: {case['data']} (mask={bin(case['mask'])} -> {result}")
        else:
            dut._log.error(f"FAIL: {case['data']} (mask={bin(case['mask'])} -> {result}, expected {case['expected']}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
