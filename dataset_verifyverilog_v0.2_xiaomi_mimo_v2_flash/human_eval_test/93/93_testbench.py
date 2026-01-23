import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_message_encoder(dut):
    """Test message encoding with case swap and vowel substitution"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.message_in.value = 0
    dut.valid_length.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 'TEST' -> 'tgst'
    # T(0x54) -> t(0x74), E(0x45) -> G(0x47), S(0x53) -> s(0x73), T(0x54) -> t(0x74)
    dut.message_in.value = 0x54455354  # 'TEST' in ASCII
    dut.valid_length.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for 17 cycles (16 processing + 1 for done)
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    # Check output: 'tgst' = 0x74677374
    expected = 0x74677374
    actual = int(dut.message_out.value)
    print(f"Test 1 - Input: 'TEST', Expected: 0x{expected:08X}, Actual: 0x{actual:08X}")
    assert actual == expected, f"Expected 0x{expected:08X}, got 0x{actual:08X}"
    assert dut.done.value == 1, "Done signal should be high"
    
    await RisingEdge(dut.clk)
    
    # Test case 2: 'Mudasir' -> 'mWDCSKR'
    # M(0x4D) -> m(0x6D), u(0x75) -> Y(0x59), d(0x64) -> D(0x44), a(0x61) -> C(0x43),
    # s(0x73) -> S(0x53), i(0x69) -> K(0x4B), r(0x72) -> R(0x52)
    # Pad to 16 chars with zeros
    dut.message_in.value = 0x4D75646173697200  # 'Mudasir' + nulls
    dut.valid_length.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    # Check first 7 characters: 'mWDCSKR' = 0x6D574443534B52
    expected = 0x6D574443534B52
    actual = int(dut.message_out.value) & 0xFFFFFFFFFFFFFF00  # Mask to 7 bytes
    print(f"Test 2 - Input: 'Mudasir', Expected: 0x{expected:014X}, Actual: 0x{actual:014X}")
    assert actual == expected, f"Expected 0x{expected:014X}, got 0x{actual:014X}"
    
    await RisingEdge(dut.clk)
    
    # Test case 3: 'YES' -> 'ygs'
    # Y(0x59) -> y(0x79), E(0x45) -> G(0x47), S(0x53) -> s(0x73)
    dut.message_in.value = 0x5945530000000000  # 'YES' + nulls
    dut.valid_length.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    expected = 0x7967730000000000
    actual = int(dut.message_out.value)
    print(f"Test 3 - Input: 'YES', Expected: 0x{expected:016X}, Actual: 0x{actual:016X}")
    assert actual == expected, f"Expected 0x{expected:016X}, got 0x{actual:016X}"
    
    await RisingEdge(dut.clk)
    
    # Test case 4: 'This is a message' -> 'tHKS KS C MGSSCGG' (17 chars, but we limit to 16)
    # Process first 16 chars: 'This is a messag' -> 'tHKS KS C MGSSCGG'
    # T(0x54) -> t(0x74), h(0x68) -> H(0x48), i(0x69) -> K(0x4B), s(0x73) -> S(0x53),
    # space(0x20) unchanged, i(0x69) -> K(0x4B), s(0x73) -> S(0x53), space(0x20) unchanged,
    # a(0x61) -> C(0x43), space(0x20) unchanged, m(0x6D) -> M(0x4D), e(0x65) -> G(0x47),
    # s(0x73) -> S(0x53), s(0x73) -> S(0x53), a(0x61) -> C(0x43), g(0x67) -> G(0x47)
    dut.message_in.value = 0x546869732069732061206D6573736167  # 'This is a messag' (16 chars)
    dut.valid_length.value = 16
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    # Expected: 'tHKS KS C MGSSCGG' = 0x74484B53204B532043204D4753534347
    expected = 0x74484B53204B532043204D4753534347
    actual = int(dut.message_out.value)
    print(f"Test 4 - Input: 'This is a messag', Expected: 0x{expected:032X}, Actual: 0x{actual:032X}")
    assert actual == expected, f"Expected 0x{expected:032X}, got 0x{actual:032X}"
    
    # Test case 5: Edge case with all vowels
    # 'AEIOUaeiou' -> 'CGKQYcgkqy'
    dut.message_in.value = 0x4145494F556165696F75000000000000  # 'AEIOUaeiou' + nulls
    dut.valid_length.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    expected = 0x43474B515963676B7179000000000000
    actual = int(dut.message_out.value)
    print(f"Test 5 - Input: 'AEIOUaeiou', Expected: 0x{expected:032X}, Actual: 0x{actual:032X}")
    assert actual == expected, f"Expected 0x{expected:032X}, got 0x{actual:032X}"
    
    print("
All 5 tests passed!")
