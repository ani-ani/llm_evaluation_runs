import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
def test_highest_power_of_2(dut):
    """Test highest_power_of_2 module with various inputs"""
    
    # Test Case 1: Input 10 -> Expected 8
    dut.n.value = 10
    await Timer(1, units='ns')
    if dut.result.value != 8:
        raise TestFailure(f"Input 10: Expected 8, got {int(dut.result.value)}")
    
    # Test Case 2: Input 19 -> Expected 16
    dut.n.value = 19
    await Timer(1, units='ns')
    if dut.result.value != 16:
        raise TestFailure(f"Input 19: Expected 16, got {int(dut.result.value)}")

    # Test Case 3: Input 32 -> Expected 32
    dut.n.value = 32
    await Timer(1, units='ns')
    if dut.result.value != 32:
        raise TestFailure(f"Input 32: Expected 32, got {int(dut.result.value)}")
        
    # Test Case 4: Input 0 -> Expected 0
    dut.n.value = 0
    await Timer(1, units='ns')
    if dut.result.value != 0:
        raise TestFailure(f"Input 0: Expected 0, got {int(dut.result.value)}")
        
    # Test Case 5: Max Value (255) -> Expected 128
    dut.n.value = 255
    await Timer(1, units='ns')
    if dut.result.value != 128:
        raise TestFailure(f"Input 255: Expected 128, got {int(dut.result.value)}")
        
    # Test Case 6: Input 1 -> Expected 1
    dut.n.value = 1
    await Timer(1, units='ns')
    if dut.result.value != 1:
        raise TestFailure(f"Input 1: Expected 1, got {int(dut.result.value)}")
        
    dut._log.info("All tests passed!")
