import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

class TypeEncoding:
    INT = 0b0001
    FLOAT = 0b0010
    STR = 0b0011

@cocotb.test()
async def test_count_integers(dut):
    """Test counting integer elements in mixed-type array"""
    
    # Test 1: Mixed types - should count 2 integers
    dut.data[0] = (TypeEncoding.INT << 4) | 1   # int 1
    dut.data[1] = (TypeEncoding.INT << 4) | 2   # int 2
    dut.data[2] = (TypeEncoding.STR << 4) | 3   # 'abc'
    dut.data[3] = (TypeEncoding.FLOAT << 4) | 4 # float 1.2
    dut.data[4] = 0
    dut.data[5] = 0
    dut.data[6] = 0
    dut.data[7] = 0
    
    await Timer(1, units='ns')
    
    if dut.count.value != 2:
        raise TestFailure(f"Test 1 failed: expected 2, got {dut.count.value}")
    print(f"Test 1 passed: Mixed types count = {dut.count.value}")
    
    # Test 2: All integers - should count 3
    dut.data[0] = (TypeEncoding.INT << 4) | 1
    dut.data[1] = (TypeEncoding.INT << 4) | 2
    dut.data[2] = (TypeEncoding.INT << 4) | 3
    dut.data[3] = 0
    dut.data[4] = 0
    dut.data[5] = 0
    dut.data[6] = 0
    dut.data[7] = 0
    
    await Timer(1, units='ns')
    
    if dut.count.value != 3:
        raise TestFailure(f"Test 2 failed: expected 3, got {dut.count.value}")
    print(f"Test 2 passed: All integers count = {dut.count.value}")
    
    # Test 3: Mixed types - should count 2
    dut.data[0] = (TypeEncoding.INT << 4) | 1
    dut.data[1] = (TypeEncoding.FLOAT << 4) | 2
    dut.data[2] = (TypeEncoding.INT << 4) | 4
    dut.data[3] = (TypeEncoding.FLOAT << 4) | 5
    dut.data[4] = 0
    dut.data[5] = 0
    dut.data[6] = 0
    dut.data[7] = 0
    
    await Timer(1, units='ns')
    
    if dut.count.value != 2:
        raise TestFailure(f"Test 3 failed: expected 2, got {dut.count.value}")
    print(f"Test 3 passed: Mixed types count = {dut.count.value}")
    
    # Test 4: No integers
    dut.data[0] = (TypeEncoding.FLOAT << 4) | 1
    dut.data[1] = (TypeEncoding.STR << 4) | 2
    dut.data[2] = 0
    dut.data[3] = 0
    dut.data[4] = 0
    dut.data[5] = 0
    dut.data[6] = 0
    dut.data[7] = 0
    
    await Timer(1, units='ns')
    
    if dut.count.value != 0:
        raise TestFailure(f"Test 4 failed: expected 0, got {dut.count.value}")
    print(f"Test 4 passed: No integers count = {dut.count.value}")
    
    # Test 5: All 8 integers
    for i in range(8):
        dut.data[i] = (TypeEncoding.INT << 4) | i
    
    await Timer(1, units='ns')
    
    if dut.count.value != 8:
        raise TestFailure(f"Test 5 failed: expected 8, got {dut.count.value}")
    print(f"Test 5 passed: All 8 integers count = {dut.count.value}")
    
    print(f"
Summary: 5/5 tests passed")