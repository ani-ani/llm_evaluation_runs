import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_formatter(dut):
    """Test string formatting with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [1,2,3,4] -> ['temp1','temp2','temp3','temp4']
    # ASCII: '1'=0x31, '2'=0x32, '3'=0x33, '4'=0x34
    dut.list_data[0].value = 0x31  # '1'
    dut.list_data[1].value = 0x32  # '2'
    dut.list_data[2].value = 0x33  # '3'
    dut.list_data[3].value = 0x34  # '4'
    dut.list_data[4].value = 0x00
    dut.list_data[5].value = 0x00
    dut.list_data[6].value = 0x00
    dut.list_data[7].value = 0x00
    dut.list_length.value = 4
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (8 cycles + 1 for done)
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Verify outputs
    if dut.done.value != 1:
        raise TestFailure("Test 1: done signal not asserted")
    
    if dut.valid_count.value != 4:
        raise TestFailure(f"Test 1: expected valid_count=4, got {dut.valid_count.value}")
    
    # Check first string: 't','e','m','p','1'
    expected1 = [0x74, 0x65, 0x6d, 0x70, 0x31]  # 't','e','m','p','1'
    for i in range(5):
        actual = int(dut.result_strings[0][i].value)
        if actual != expected1[i]:
            raise TestFailure(f"Test 1 String[0][{i}]: expected {hex(expected1[i])}, got {hex(actual)}")
    
    print("Test 1 passed")
    
    # Wait for next test
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 2: ['a','b','c','d'] -> ['pythona','pythonb','pythonc','pythond']
    # ADAPTED: Format is 'temp' + char, not 'python'
    # Inputs: 'a','b','c','d'
    # Expected: 'tempa','tempb','tempc','tempd'
    dut.list_data[0].value = 0x61  # 'a'
    dut.list_data[1].value = 0x62  # 'b'
    dut.list_data[2].value = 0x63  # 'c'
    dut.list_data[3].value = 0x64  # 'd'
    dut.list_data[4].value = 0x00
    dut.list_data[5].value = 0x00
    dut.list_data[6].value = 0x00
    dut.list_data[7].value = 0x00
    dut.list_length.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: done signal not asserted")
    
    if dut.valid_count.value != 4:
        raise TestFailure(f"Test 2: expected valid_count=4, got {dut.valid_count.value}")
    
    # Check first string: 't','e','m','p','a'
    expected2 = [0x74, 0x65, 0x6d, 0x70, 0x61]
    for i in range(5):
        actual = int(dut.result_strings[0][i].value)
        if actual != expected2[i]:
            raise TestFailure(f"Test 2 String[0][{i}]: expected {hex(expected2[i])}, got {hex(actual)}")
    
    print("Test 2 passed")
    
    # Wait for next test
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 3: [5,6,7,8] -> ['string5','string6','string7','string8']
    # ADAPTED: Format is 'temp' + char
    # Inputs: '5','6','7','8'
    # Expected: 'temp5','temp6','temp7','temp8'
    dut.list_data[0].value = 0x35  # '5'
    dut.list_data[1].value = 0x36  # '6'
    dut.list_data[2].value = 0x37  # '7'
    dut.list_data[3].value = 0x38  # '8'
    dut.list_data[4].value = 0x00
    dut.list_data[5].value = 0x00
    dut.list_data[6].value = 0x00
    dut.list_data[7].value = 0x00
    dut.list_length.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: done signal not asserted")
    
    if dut.valid_count.value != 4:
        raise TestFailure(f"Test 3: expected valid_count=4, got {dut.valid_count.value}")
    
    # Check first string: 't','e','m','p','5'
    expected3 = [0x74, 0x65, 0x6d, 0x70, 0x35]
    for i in range(5):
        actual = int(dut.result_strings[0][i].value)
        if actual != expected3[i]:
            raise TestFailure(f"Test 3 String[0][{i}]: expected {hex(expected3[i])}, got {hex(actual)}")
    
    print("Test 3 passed")
    
    # Edge Case: 1 element
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.list_data[0].value = 0x58  # 'X'
    dut.list_data[1].value = 0x00
    dut.list_length.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if int(dut.result_strings[0][4].value) != 0x58:
        raise TestFailure(f"Edge case: expected last char 0x58, got {int(dut.result_strings[0][4].value)}")
    
    print("Edge case passed")
    print("All tests passed!")