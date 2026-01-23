import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_drop_empty(dut):
    """Test dropping empty (None) items from dictionary"""
    
    # Test Case 1: {'c1': 'Red', 'c2': 'Green', 'c3':None}
    # Keys: c1='c'(0x63), c2='c'(0x63), c3='c'(0x63)
    # Values: 'R'(0x52), 'G'(0x47), None(0xFF)
    dut.key_0.value = ord('c')
    dut.key_1.value = ord('c')
    dut.key_2.value = ord('c')
    dut.key_3.value = 0
    dut.key_4.value = 0
    dut.key_5.value = 0
    dut.key_6.value = 0
    dut.key_7.value = 0
    
    dut.val_0.value = ord('R')
    dut.val_1.value = ord('G')
    dut.val_2.value = 0xFF  # None
    dut.val_3.value = 0
    dut.val_4.value = 0
    dut.val_5.value = 0
    dut.val_6.value = 0
    dut.val_7.value = 0
    
    await Timer(10, units='ns')
    
    # Expected: {'c1': 'Red', 'c2': 'Green'} -> 2 pairs
    assert dut.count.value == 2, f"Expected count 2, got {dut.count.value}"
    assert dut.out_key_0.value == ord('c'), f"Expected key_0='c', got {dut.out_key_0.value}"
    assert dut.out_val_0.value == ord('R'), f"Expected val_0='R', got {dut.out_val_0.value}"
    assert dut.out_key_1.value == ord('c'), f"Expected key_1='c', got {dut.out_key_1.value}"
    assert dut.out_val_1.value == ord('G'), f"Expected val_1='G', got {dut.out_val_1.value}"
    
    print("Test 1 passed")
    
    # Test Case 2: {'c1': 'Red', 'c2': None, 'c3':None}
    dut.val_1.value = 0xFF  # None
    dut.val_2.value = 0xFF  # None
    
    await Timer(10, units='ns')
    
    # Expected: {'c1': 'Red'} -> 1 pair
    assert dut.count.value == 1, f"Expected count 1, got {dut.count.value}"
    assert dut.out_key_0.value == ord('c'), f"Expected key_0='c', got {dut.out_key_0.value}"
    assert dut.out_val_0.value == ord('R'), f"Expected val_0='R', got {dut.out_val_0.value}"
    
    print("Test 2 passed")
    
    # Test Case 3: {'c1': None, 'c2': 'Green', 'c3':None}
    dut.val_0.value = 0xFF  # None
    dut.val_1.value = ord('G')  # Green
    dut.val_2.value = 0xFF  # None
    
    await Timer(10, units='ns')
    
    # Expected: {'c2': 'Green'} -> 1 pair
    assert dut.count.value == 1, f"Expected count 1, got {dut.count.value}"
    assert dut.out_key_0.value == ord('c'), f"Expected key_0='c', got {dut.out_key_0.value}"
    assert dut.out_val_0.value == ord('G'), f"Expected val_0='G', got {dut.out_val_0.value}"
    
    print("Test 3 passed")
    
    # Edge Case 4: All None
    for i in range(8):
        setattr(dut, f'val_{i}', 0xFF)
    
    await Timer(10, units='ns')
    assert dut.count.value == 0, f"Expected count 0 for all None, got {dut.count.value}"
    print("Test 4 passed")
    
    # Edge Case 5: All non-None (8 items)
    dut.key_0.value = ord('a')
    dut.key_1.value = ord('b')
    dut.key_2.value = ord('c')
    dut.key_3.value = ord('d')
    dut.key_4.value = ord('e')
    dut.key_5.value = ord('f')
    dut.key_6.value = ord('g')
    dut.key_7.value = ord('h')
    dut.val_0.value = 0x01
    dut.val_1.value = 0x02
    dut.val_2.value = 0x03
    dut.val_3.value = 0x04
    dut.val_4.value = 0x05
    dut.val_5.value = 0x06
    dut.val_6.value = 0x07
    dut.val_7.value = 0x08
    
    await Timer(10, units='ns')
    assert dut.count.value == 8, f"Expected count 8, got {dut.count.value}"
    assert dut.out_key_0.value == ord('a'), f"Expected key_0='a', got {dut.out_key_0.value}"
    assert dut.out_val_3.value == 0x04, f"Expected val_3=0x04, got {dut.out_val_3.value}"
    print("Test 5 passed")
    
    print("All tests passed!")