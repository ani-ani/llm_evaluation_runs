import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_eat_carrots(dut):
    """Test the eat_carrots combinational module"""
    
    # Test case 1: eat(5, 6, 10) -> [11, 4]
    dut.number.value = 5
    dut.need.value = 6
    dut.remaining.value = 10
    await Timer(10, units='ns')
    assert int(dut.total_eaten.value) == 11, f"Expected total_eaten=11, got {int(dut.total_eaten.value)}"
    assert int(dut.left_over.value) == 4, f"Expected left_over=4, got {int(dut.left_over.value)}"
    
    # Test case 2: eat(4, 8, 9) -> [12, 1]
    dut.number.value = 4
    dut.need.value = 8
    dut.remaining.value = 9
    await Timer(10, units='ns')
    assert int(dut.total_eaten.value) == 12, f"Expected total_eaten=12, got {int(dut.total_eaten.value)}"
    assert int(dut.left_over.value) == 1, f"Expected left_over=1, got {int(dut.left_over.value)}"
    
    # Test case 3: eat(1, 10, 10) -> [11, 0]
    dut.number.value = 1
    dut.need.value = 10
    dut.remaining.value = 10
    await Timer(10, units='ns')
    assert int(dut.total_eaten.value) == 11, f"Expected total_eaten=11, got {int(dut.total_eaten.value)}"
    assert int(dut.left_over.value) == 0, f"Expected left_over=0, got {int(dut.left_over.value)}"
    
    # Test case 4: eat(2, 11, 5) -> [7, 0]
    dut.number.value = 2
    dut.need.value = 11
    dut.remaining.value = 5
    await Timer(10, units='ns')
    assert int(dut.total_eaten.value) == 7, f"Expected total_eaten=7, got {int(dut.total_eaten.value)}"
    assert int(dut.left_over.value) == 0, f"Expected left_over=0, got {int(dut.left_over.value)}"
    
    # Test case 5: eat(4, 5, 7) -> [9, 2]
    dut.number.value = 4
    dut.need.value = 5
    dut.remaining.value = 7
    await Timer(10, units='ns')
    assert int(dut.total_eaten.value) == 9, f"Expected total_eaten=9, got {int(dut.total_eaten.value)}"
    assert int(dut.left_over.value) == 2, f"Expected left_over=2, got {int(dut.left_over.value)}"
    
    # Test case 6: eat(4, 5, 1) -> [5, 0]
    dut.number.value = 4
    dut.need.value = 5
    dut.remaining.value = 1
    await Timer(10, units='ns')
    assert int(dut.total_eaten.value) == 5, f"Expected total_eaten=5, got {int(dut.total_eaten.value)}"
    assert int(dut.left_over.value) == 0, f"Expected left_over=0, got {int(dut.left_over.value)}"
    
    # Edge case: all zeros
    dut.number.value = 0
    dut.need.value = 0
    dut.remaining.value = 0
    await Timer(10, units='ns')
    assert int(dut.total_eaten.value) == 0, f"Expected total_eaten=0, got {int(dut.total_eaten.value)}"
    assert int(dut.left_over.value) == 0, f"Expected left_over=0, got {int(dut.left_over.value)}"
    
    # Edge case: need much larger than remaining
    dut.number.value = 100
    dut.need.value = 200
    dut.remaining.value = 50
    await Timer(10, units='ns')
    assert int(dut.total_eaten.value) == 150, f"Expected total_eaten=150, got {int(dut.total_eaten.value)}"
    assert int(dut.left_over.value) == 0, f"Expected left_over=0, got {int(dut.left_over.value)}"
    
    print(f"All tests passed!")
