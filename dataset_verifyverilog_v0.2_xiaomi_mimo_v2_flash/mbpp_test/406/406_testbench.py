import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_parity_checker(dut):
    """Test parity checker module"""
    
    # Test case 1: 12 (binary 1100) - even parity
    dut.data_in.value = 12
    await Timer(10, units='ns')
    assert dut.parity.value == 0, f"Test 1 failed: Expected parity 0 for 12, got {dut.parity.value}"
    print(f"Test 1 passed: data_in=12, parity={dut.parity.value} (even)")
    
    # Test case 2: 7 (binary 111) - odd parity
    dut.data_in.value = 7
    await Timer(10, units='ns')
    assert dut.parity.value == 1, f"Test 2 failed: Expected parity 1 for 7, got {dut.parity.value}"
    print(f"Test 2 passed: data_in=7, parity={dut.parity.value} (odd)")
    
    # Test case 3: 10 (binary 1010) - even parity
    dut.data_in.value = 10
    await Timer(10, units='ns')
    assert dut.parity.value == 0, f"Test 3 failed: Expected parity 0 for 10, got {dut.parity.value}"
    print(f"Test 3 passed: data_in=10, parity={dut.parity.value} (even)")
    
    # Additional edge cases
    # Test 4: 0 (all zeros) - even parity
    dut.data_in.value = 0
    await Timer(10, units='ns')
    assert dut.parity.value == 0, f"Test 4 failed: Expected parity 0 for 0, got {dut.parity.value}"
    print(f"Test 4 passed: data_in=0, parity={dut.parity.value} (even)")
    
    # Test 5: 1 (binary 1) - odd parity
    dut.data_in.value = 1
    await Timer(10, units='ns')
    assert dut.parity.value == 1, f"Test 5 failed: Expected parity 1 for 1, got {dut.parity.value}"
    print(f"Test 5 passed: data_in=1, parity={dut.parity.value} (odd)")
    
    # Test 6: 0xFFFFFFFF (all 1s, 32 ones) - even parity
    dut.data_in.value = 0xFFFFFFFF
    await Timer(10, units='ns')
    assert dut.parity.value == 0, f"Test 6 failed: Expected parity 0 for 0xFFFFFFFF, got {dut.parity.value}"
    print(f"Test 6 passed: data_in=0xFFFFFFFF, parity={dut.parity.value} (even)")
    
    print("
All 6/6 tests passed!")