import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_signed_binary_converter(dut):
    """Test signed binary conversion"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.binary_in.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 10000 (binary) = 16 decimal
    # Expected: +0000 (length 5)
    # signed_out: LSB first: 01 00 00 00 00 => 0x000001 (binary: 000000000000000001)
    dut.binary_in.value = 0b10000
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (18 cycles)
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.length.value == 5, f"Expected length 5, got {dut.length.value}"
    # Check output: 01 00 00 00 00 = 0x000001 (bits reversed due to [1:0] being LSB)
    expected_out = 0b01_00_00_00_00  # 2-bit groups
    assert dut.signed_out.value == expected_out, f"Expected {bin(expected_out)}, got {bin(dut.signed_out.value)}"
    print(f"Test 1 passed: 10000 -> +0000")
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 1111 (binary) = 15 decimal
    # Expected: +000- (length 5)
    # LSB: bit0=1, no carry -> +1 (01)
    # bit1=1 -> result of 1+1? Wait, let's trace properly
    # 15 = 16 - 1 = 2^4 - 2^0 -> digits: +1 at pos4, 0, 0, 0, -1 at pos0
    # Output bits LSB first: pos0=-1 (11), pos1=0 (00), pos2=0 (00), pos3=0 (00), pos4=+1 (01)
    # So signed_out should be: 11 00 00 00 01 = 0b0100000011 = 0x103
    dut.binary_in.value = 0b1111
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1
    assert dut.length.value == 5
    expected_out = 0b01_00_00_00_11  # 01 at MSB, 11 at LSB
    assert dut.signed_out.value == expected_out, f"Expected {bin(expected_out)}, got {bin(dut.signed_out.value)}"
    print(f"Test 2 passed: 1111 -> +000-")
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: 10111 (binary) = 23 decimal
    # Expected: ++00- (length 5)
    # 23 = 16 + 8 - 1 = 2^4 + 2^3 - 2^0
    # Digits: pos4:+1, pos3:+1, pos2:0, pos1:0, pos0:-1
    # LSB first: 11 00 00 01 01
    dut.binary_in.value = 0b10111
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1
    assert dut.length.value == 5
    expected_out = 0b01_01_00_00_11
    assert dut.signed_out.value == expected_out, f"Expected {bin(expected_out)}, got {bin(dut.signed_out.value)}"
    print(f"Test 3 passed: 10111 -> ++00-")
    
    print("All 3 tests passed")
