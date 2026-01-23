import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
def test_add_basic(dut):
    """Test basic addition cases"""
    # Test case 1: 2 + 3 = 5
    dut.x.value = 2
    dut.y.value = 3
    await Timer(10, units='ns')
    assert int(dut.result.value) == 5, f"Expected 5, got {int(dut.result.value)}"
    
    # Test case 2: 5 + 7 = 12
    dut.x.value = 5
    dut.y.value = 7
    await Timer(10, units='ns')
    assert int(dut.result.value) == 12, f"Expected 12, got {int(dut.result.value)}"
    
    # Test case 3: 7 + 5 = 12
    dut.x.value = 7
    dut.y.value = 5
    await Timer(10, units='ns')
    assert int(dut.result.value) == 12, f"Expected 12, got {int(dut.result.value)}"

@cocotb.test()
def test_add_edge_cases(dut):
    """Test edge cases"""
    # Test case 1: 0 + 1 = 1
    dut.x.value = 0
    dut.y.value = 1
    await Timer(10, units='ns')
    assert int(dut.result.value) == 1, f"Expected 1, got {int(dut.result.value)}"
    
    # Test case 2: 1 + 0 = 1
    dut.x.value = 1
    dut.y.value = 0
    await Timer(10, units='ns')
    assert int(dut.result.value) == 1, f"Expected 1, got {int(dut.result.value)}"
    
    # Test case 3: 0 + 0 = 0
    dut.x.value = 0
    dut.y.value = 0
    await Timer(10, units='ns')
    assert int(dut.result.value) == 0, f"Expected 0, got {int(dut.result.value)}"

@cocotb.test()
def test_add_random(dut):
    """Test random addition cases"""
    random.seed(42)
    test_count = 0
    passed_count = 0
    
    for i in range(100):
        x = random.randint(0, 1000)
        y = random.randint(0, 1000)
        expected = x + y
        
        dut.x.value = x
        dut.y.value = y
        await Timer(10, units='ns')
        
        result = int(dut.result.value)
        test_count += 1
        if result == expected:
            passed_count += 1
        
        assert result == expected, f"Test {i}: {x} + {y} = {expected}, got {result}"
    
    print(f"
Random tests: {passed_count}/{test_count} passed")
