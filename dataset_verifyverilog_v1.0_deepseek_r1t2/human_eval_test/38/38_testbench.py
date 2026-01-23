import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_cyclic_codec(dut):
    """Test cyclic encode/decode module with various strings."""
    
    def is_value_defined(value):
        """Check if a cocotb value is defined (not X or Z)."""
        try:
            int(value)
            return True
        except ValueError:
            return False
    
    def encode_cyclic(s):
        """Python reference implementation for encoding."""
        groups = [s[(3 * i):min((3 * i + 3), len(s))] for i in range((len(s) + 2) // 3)]
        groups = [(group[1:] + group[0]) if len(group) == 3 else group for group in groups]
        return "".join(groups)
    
    def decode_cyclic(s):
        """Python reference implementation for decoding."""
        groups = [s[(3 * i):min((3 * i + 3), len(s))] for i in range((len(s) + 2) // 3)]
        groups = [(group[-1] + group[:-1]) if len(group) == 3 else group for group in groups]
        return "".join(groups)
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.mode.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ("abc", "encode"),
        ("bcd", "encode"),
        ("xyz", "encode"),
        ("abcdefgh", "encode"),
        ("a", "encode"),
        ("bc", "encode"),
        ("bca", "decode"),
        ("cab", "decode"),
        ("efg", "decode"),
        ("xyzabc", "decode"),
        ("a", "decode"),
        ("bc", "decode"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_str, mode_str in test_cases:
        dut._log.info(f"Testing: {test_str!r} ({mode_str})")
        
        # Determine mode
        mode = 1 if mode_str == "decode" else 0
        dut.mode.value = mode
        
        # Generate expected result
        if mode == 0:
            expected = encode_cyclic(test_str)
        else:
            expected = decode_cyclic(test_str)
        
        dut._log.info(f"Expected: {expected!r}")
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed input characters
        output_chars = []
        char_index = 0
        output_index = 0
        
        # Process up to MAX_LEN cycles
        for cycle in range(100):
            # Provide input if still have characters
            if char_index < len(test_str):
                dut.valid_in.value = 1
                dut.char_in.value = ord(test_str[char_index])
                char_index += 1
            else:
                dut.valid_in.value = 0
                dut.char_in.value = 0
            
            await RisingEdge(dut.clk)
            
            # Read output
            if is_value_defined(dut.valid_out.value) and dut.valid_out.value == 1:
                if is_value_defined(dut.char_out.value):
                    output_chars.append(chr(int(dut.char_out.value)))
                    output_index += 1
            
            # Check done signal
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout: done not asserted after 100 cycles for '{test_str}'")
        
        # Verify result
        output_str = "".join(output_chars)
        dut._log.info(f"Got: {output_str!r}")
        
        if output_str != expected:
            raise TestFailure(f"Test failed: input={test_str!r}, expected={expected!r}, got={output_str!r}")
        
        passed += 1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
