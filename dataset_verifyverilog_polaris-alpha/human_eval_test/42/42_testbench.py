import cocotb
from cocotb.triggers import Timer
from cocotb.types import Array

@cocotb.test()
async def test_list_increment(dut):
    # Original test cases adapted to 8-element max
    test_cases = [
        ([], [0]*8),
        ([3, 2, 1] + [0]*5, [4, 3, 2] + [0]*5),
        ([5, 2, 5, 2, 3, 3, 9, 0], [6, 3, 6, 3, 4, 4, 10, 1])
    ]
    passed = 0
    
    for input_list, expected in test_cases:
        # Convert Python list to Verilog vector
        input_vector = 0
        for i, val in enumerate(input_list):
            input_vector |= val << (i*8)
        
        # Apply to DUT
        dut.l.value = input_vector
        await Timer(1, units='ns')
        
        # Check results
        errors = []
        for i in range(8):
            actual = (dut.result.value >> (i*8)) & 0xFF
            exp_val = expected[i] if i < len(expected) else 0
            
            if actual != exp_val:
                errors.append(f"Element {i}: got {int(actual)}, expected {exp_val}")
        
        if not errors:
            passed += 1
            dut._log.info(f"PASS: {input_list} -> {expected}")
        else:
            dut._log.error(f"FAIL: {input_list}
Errors: {' | '.join(errors)}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total