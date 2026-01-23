import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_remove_uppercase(dut):
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to pack string into 128-bit integer
    def pack_str(s):
        val = 0
        # Pad to 16 chars with nulls (0x00) if necessary, or truncate if longer
        s_padded = s.ljust(16, '\x00')[:16]
        for i, char in enumerate(s_padded):
            val |= ord(char) << (120 - i*8) # Big-endian packing (char 0 at MSB) or Little-endian depending on test logic. Let's assume byte 0 is MSB for standard string representation, but verilog array indexing usually [127:120] is index 0.
        return val

    # Helper to unpack 128-bit integer to string
    def unpack_str(val):
        s = ''
        # Extract 16 bytes from MSB [127:120] down to [7:0]
        for i in range(16):
            byte_val = (val >> (120 - i*8)) & 0xFF
            if byte_val != 0:
                s += chr(byte_val)
        return s

    # Test Case 1: 'cAstyoUrFavoRitETVshoWs' -> 'cstyoravoitshos'
    # Input: 23 chars, let's test logic. Packed input.
    input1 = 'cAstyoUrFavoRitETVshoWs'
    dut.str_in.value = pack_str(input1)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done (expected ~17 cycles)
    timeout = 0
    while not dut.done.value and timeout < 30:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    
    result_val = int(dut.str_out.value)
    result_str = unpack_str(result_val)
    
    # Expected: 'cstyoravoitshos' (16 chars)
    expected = 'cstyoravoitshos'
    
    print(f"Test 1: Input='{input1}', Output='{result_str}', Expected='{expected}'")
    assert result_str == expected, f"Mismatch: got {result_str}"

    # Wait for idle state or reset for next test
    await RisingEdge(dut.clk)

    # Test Case 2: 'wAtchTheinTernEtrAdIo' -> 'wtchheinerntrdo'
    input2 = 'wAtchTheinTernEtrAdIo'
    dut.str_in.value = pack_str(input2)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while not dut.done.value and timeout < 30:
        await RisingEdge(dut.clk)
        timeout += 1

    result_val = int(dut.str_out.value)
    result_str = unpack_str(result_val)
    expected = 'wtchheinerntrdo'
    print(f"Test 2: Input='{input2}', Output='{result_str}', Expected='{expected}'")
    assert result_str == expected, f"Mismatch: got {result_str}"

    await RisingEdge(dut.clk)

    # Test Case 3: 'VoicESeaRchAndreComMendaTionS' -> 'oiceachndreomendaion'
    input3 = 'VoicESeaRchAndreComMendaTionS'
    dut.str_in.value = pack_str(input3)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while not dut.done.value and timeout < 30:
        await RisingEdge(dut.clk)
        timeout += 1

    result_val = int(dut.str_out.value)
    result_str = unpack_str(result_val)
    expected = 'oiceachndreomendaion'
    print(f"Test 3: Input='{input3}', Output='{result_str}', Expected='{expected}'")
    assert result_str == expected, f"Mismatch: got {result_str}"
