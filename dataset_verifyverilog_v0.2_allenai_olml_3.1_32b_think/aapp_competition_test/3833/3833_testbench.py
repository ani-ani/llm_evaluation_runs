import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_schedule_optimizer(dut):
    """Test the schedule optimizer module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = ord('0')
    dut.valid_in.value = 0
    dut.s_length.value = 0
    dut.t_length.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: s="101101", t="110" -> "110110"
    dut._log.info("Test 1: s=101101, t=110")
    s1 = "101101"
    t1 = "110"
    
    # Count zeros and ones in s
    zeros_s = s1.count('0')
    ones_s = s1.count('1')
    zeros_t = t1.count('0')
    ones_t = t1.count('1')
    
    dut._log.info(f"  Counts: s zeros={zeros_s}, ones={ones_s}; t zeros={zeros_t}, ones={ones_t}")
    
    # Expected output
    expected = "110110"
    dut._log.info(f"  Expected: {expected}")
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.s_length.value = len(s1)
    dut.t_length.value = len(t1)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed s characters
    for char in s1:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Feed t characters
    for char in t1:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Wait for output
    output = ""
    timeout = 200
    count = 0
    while count < timeout:
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output += chr(dut.char_out.value)
        if dut.done.value:
            break
        count += 1
    
    if count >= timeout:
        raise TestFailure(f"Test 1 timed out! Output: {output}")
    
    dut._log.info(f"  Got: {output}")
    assert output == expected, f"Test 1 failed: expected {expected}, got {output}"
    
    # Test case 2: s="10", t="11100" -> "01"
    dut._log.info("Test 2: s=10, t=11100")
    s2 = "10"
    t2 = "11100"
    
    zeros_s = s2.count('0')
    ones_s = s2.count('1')
    zeros_t = t2.count('0')
    ones_t = t2.count('1')
    
    dut._log.info(f"  Counts: s zeros={zeros_s}, ones={ones_s}; t zeros={zeros_t}, ones={ones_t}")
    expected2 = "01"
    dut._log.info(f"  Expected: {expected2}")
    
    # Reset for new test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.s_length.value = len(s2)
    dut.t_length.value = len(t2)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed s
    for char in s2:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Feed t
    for char in t2:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Get output
    output = ""
    timeout = 200
    count = 0
    while count < timeout:
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output += chr(dut.char_out.value)
        if dut.done.value:
            break
        count += 1
    
    if count >= timeout:
        raise TestFailure(f"Test 2 timed out! Output: {output}")
    
    dut._log.info(f"  Got: {output}")
    assert output == expected2, f"Test 2 failed: expected {expected2}, got {output}"
    
    # Test case 3: s="10010110", t="100011" -> "10001101"
    dut._log.info("Test 3: s=10010110, t=100011")
    s3 = "10010110"
    t3 = "100011"
    
    zeros_s = s3.count('0')
    ones_s = s3.count('1')
    zeros_t = t3.count('0')
    ones_t = t3.count('1')
    
    dut._log.info(f"  Counts: s zeros={zeros_s}, ones={ones_s}; t zeros={zeros_t}, ones={ones_t}")
    expected3 = "10001101"
    dut._log.info(f"  Expected: {expected3}")
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.s_length.value = len(s3)
    dut.t_length.value = len(t3)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed s
    for char in s3:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Feed t
    for char in t3:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Get output
    output = ""
    timeout = 200
    count = 0
    while count < timeout:
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output += chr(dut.char_out.value)
        if dut.done.value:
            break
        count += 1
    
    if count >= timeout:
        raise TestFailure(f"Test 3 timed out! Output: {output}")
    
    dut._log.info(f"  Got: {output}")
    assert output == expected3, f"Test 3 failed: expected {expected3}, got {output}"
    
    # Test case 4: Edge case with zeros only
    dut._log.info("Test 4: s=00000000, t=0000")
    s4 = "00000000"
    t4 = "0000"
    
    zeros_s = s4.count('0')
    ones_s = s4.count('1')
    zeros_t = t4.count('0')
    ones_t = t4.count('1')
    
    dut._log.info(f"  Counts: s zeros={zeros_s}, ones={ones_s}; t zeros={zeros_t}, ones={ones_t}")
    expected4 = "00000000"
    dut._log.info(f"  Expected: {expected4}")
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.s_length.value = len(s4)
    dut.t_length.value = len(t4)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed s
    for char in s4:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Feed t
    for char in t4:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Get output
    output = ""
    timeout = 200
    count = 0
    while count < timeout:
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output += chr(dut.char_out.value)
        if dut.done.value:
            break
        count += 1
    
    if count >= timeout:
        raise TestFailure(f"Test 4 timed out! Output: {output}")
    
    dut._log.info(f"  Got: {output}")
    assert output == expected4, f"Test 4 failed: expected {expected4}, got {output}"
    
    # Test case 5: Ones only
    dut._log.info("Test 5: s=11111111, t=1")
    s5 = "11111111"
    t5 = "1"
    
    zeros_s = s5.count('0')
    ones_s = s5.count('1')
    zeros_t = t5.count('0')
    ones_t = t5.count('1')
    
    dut._log.info(f"  Counts: s zeros={zeros_s}, ones={ones_s}; t zeros={zeros_t}, ones={ones_t}")
    expected5 = "11111111"
    dut._log.info(f"  Expected: {expected5}")
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.s_length.value = len(s5)
    dut.t_length.value = len(t5)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed s
    for char in s5:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Feed t
    for char in t5:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Get output
    output = ""
    timeout = 200
    count = 0
    while count < timeout:
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output += chr(dut.char_out.value)
        if dut.done.value:
            break
        count += 1
    
    if count >= timeout:
        raise TestFailure(f"Test 5 timed out! Output: {output}")
    
    dut._log.info(f"  Got: {output}")
    assert output == expected5, f"Test 5 failed: expected {expected5}, got {output}"
    
    # Summary
    dut._log.info("All 5 tests passed!")