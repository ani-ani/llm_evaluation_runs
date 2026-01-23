import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_toggle_middle_bits(dut):
    """Test toggle_middle_bits module with various test cases"""
    
    # Test cases: (input, expected_output)
    test_cases = [
        (9, 15),      # 0x09 -> 0x0F
        (10, 12),     # 0x0A -> 0x0C
        (11, 13),     # 0x0B -> 0x0D
        (129, 127),   # 0x81 -> 0x7F (0b10000001 -> 0b01111111)
        (77, 227),    # 0x4D -> 0xE3 (0b01001101 -> 0b11100011)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        
        # Check result
        if result == expected:
            passed += 1
            dut._log.info(f"Test passed: toggle_middle_bits({n} = 0x{n:02X}) = {result} (0x{result:02X}), expected {expected} (0x{expected:02X})")
        else:
            dut._log.error(f"Test failed: toggle_middle_bits({n} = 0x{n:02X}) = {result} (0x{result:02X}), expected {expected} (0x{expected:02X})")
            raise TestFailure(f"Result mismatch for input {n}")
    
    print(f"
{'='*50}")
    print(f"Summary: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    if passed == total:
        dut._log.info(f"All {total} tests passed!")
    else:
        dut._log.error(f"{total - passed} tests failed!")