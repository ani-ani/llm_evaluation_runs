import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_combinations(dut):
    # Note: Elements are indexed by 2-bit codes - mapping is arbitrary
    test_inputs = [
        [0, 1, 2, 3]  # Generic 4-element test
    ]
    
    # Expected output: 16 combinations from 0000 to 1111
    expected = [i for i in range(16)]
    
    passed = 0
    for inp in test_inputs:
        dut.elements.value = inp
        await Timer(1, units='ns')
        
        # Compare all outputs
        for i in range(16):
            actual = LogicArray(dut.all_combinations[i].value).integer
            if actual == i:
                passed += 1
                dut._log.info(f"Pattern {i:04b}: PASS")
            else:
                dut._log.error(f"Pattern {i:04b}: FAIL (got {actual:04b}, expected {i:04b})")
    
    dut._log.info(f"{passed}/{16*len(test_inputs)} bitmask patterns verified")
    assert passed == 16*len(test_inputs), f"Failed {16*len(test_inputs)-passed} tests"