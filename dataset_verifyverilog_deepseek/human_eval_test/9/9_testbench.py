import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_rolling_max(dut):
    """Test rolling maximum for various input sizes"""
    test_cases = [
        (0, [], []),
        (4, [1, 2, 3, 4], [1, 2, 3, 4]),
        (4, [4, 3, 2, 1], [4, 4, 4, 4]),
        (5, [3, 2, 3, 100, 3], [3, 3, 3, 100, 100])
    ]
    
    passed = 0
    for size, numbers, expected in test_cases:
        # Pack inputs
        packed_in = 0
        for i, num in enumerate(numbers):
            packed_in |= (num & 0xFF) << (i*8)
        
        # Apply inputs
        dut.size.value = size
        dut.numbers.value = packed_in
        await Timer(1, units='ns')
        
        # Unpack outputs (only check valid elements)
        valid = True
        for i in range(size):
            actual = (dut.result.value >> (i*8)) & 0xFF
            if actual != expected[i]:
                dut._log.error(f"FAIL @pos {i}: size={size}, input={numbers}, expected={expected}, actual={actual}")
                valid = False
                
        if valid:
            passed += 1
            dut._log.info(f"PASS: size={size}, input={numbers}, expected={expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)