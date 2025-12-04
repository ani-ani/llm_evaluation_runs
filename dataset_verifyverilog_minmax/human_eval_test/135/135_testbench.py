import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_can_arrange(dut):
    test_cases = [
        {'arr': [1,2,4,3,5], 'size':5, 'expected':3},
        {'arr': [1,2,4,5], 'size':4, 'expected':-1},
        {'arr': [1,4,2,5,6,7,8,9,10], 'size':9, 'expected':2},
        {'arr': [4,8,5,7,3], 'size':5, 'expected':4},
        {'arr': [], 'size':0, 'expected':-1}
    ]

    passed = 0
    for tc in test_cases:
        # Pad array to 16 elements with zeros
        padded_arr = tc['arr'] + [0]*(16 - len(tc['arr']))
        
        # Drive inputs
        for i in range(16):
            dut.arr[i].value = padded_arr[i]
        dut.size.value = tc['size']
        
        await Timer(1, units='ns')
        
        expected = 31 if tc['expected'] == -1 else tc['expected']
        actual = dut.result.value.integer
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {tc['arr']} -> {tc['expected']}")
        else:
            dut._log.error(f"FAIL: {tc['arr']} -> {actual} (expected {expected})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)