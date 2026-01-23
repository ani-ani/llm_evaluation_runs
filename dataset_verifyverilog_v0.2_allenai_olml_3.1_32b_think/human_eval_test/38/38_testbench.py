import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Python reference implementation
def encode_cyclic(s: str):
    groups = [s[(3 * i):min((3 * i + 3), len(s))] for i in range((len(s) + 2) // 3)]
    groups = [(group[1:] + group[0]) if len(group) == 3 else group for group in groups]
    return "".join(groups)

def decode_cyclic_python(encoded: str):
    """Reverse the cyclic encoding"""
    groups = [encoded[(3 * i):min((3 * i + 3), len(encoded))] for i in range((len(encoded) + 2) // 3)]
    result = []
    for group in groups:
        if len(group) == 3:
            # bca -> abc: rotate right by 1
            result.append(group[2] + group[0] + group[1])
        else:
            result.append(group)
    return "".join(result)

@cocotb.test()
async def test_cyclic_decode_basic(dut):
    """Test basic decoding functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_in.value = 0
    dut.str_length.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: length 3 (full group)
    # encode "abc" -> "bca", decode "bca" -> "abc"
    test_str = "abc"
    encoded = encode_cyclic(test_str)
    dut._log.info(f"Test 1: Input '{test_str}', Encoded '{encoded}'")
    
    # Start sequence
    dut.start.value = 1
    dut.str_length.value = len(encoded)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed characters serially
    output_chars = []
    char_index = 0
    timeout = 50
    
    for i, char in enumerate(encoded):
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        
        # Wait for output with timeout
        for _ in range(timeout):
            if dut.char_out_valid.value:
                output_chars.append(chr(int(dut.decoded_char.value)))
                break
            await RisingEdge(dut.clk)
    
    # Wait for any remaining outputs
    for _ in range(timeout):
        if dut.done.value:
            break
        if dut.char_out_valid.value:
            output_chars.append(chr(int(dut.decoded_char.value)))
        await RisingEdge(dut.clk)
    
    decoded_result = "".join(output_chars)
    dut._log.info(f"Decoded result: '{decoded_result}'")
    assert decoded_result == test_str, f"Expected '{test_str}', got '{decoded_result}'"
    
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_cyclic_decode_length_4(dut):
    """Test length 4: abc|d -> bca|d -> decode to abc|d"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_str = "abcd"
    encoded = encode_cyclic(test_str)
    dut._log.info(f"Test 2: Input '{test_str}', Encoded '{encoded}'")
    
    dut.start.value = 1
    dut.str_length.value = len(encoded)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    output_chars = []
    for char in encoded:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        
        # Wait for valid output
        timeout = 0
        while not dut.char_out_valid.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
        if dut.char_out_valid.value:
            output_chars.append(chr(int(dut.decoded_char.value)))
    
    # Drain remaining
    for _ in range(10):
        if dut.done.value:
            break
        if dut.char_out_valid.value:
            output_chars.append(chr(int(dut.decoded_char.value)))
        await RisingEdge(dut.clk)
    
    decoded_result = "".join(output_chars)
    dut._log.info(f"Decoded result: '{decoded_result}'")
    assert decoded_result == test_str, f"Expected '{test_str}', got '{decoded_result}'"

@cocotb.test()
async def test_cyclic_decode_edge_cases(dut):
    """Test edge cases: length 1, 2, 5, 8"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        "a",      # length 1: no change
        "ab",     # length 2: no change
        "abcde",  # length 5: abc|de -> bca|de -> abc|de
        "abcdefgh", # length 8: abc|def|gh -> bca|def|gh -> abc|def|gh
    ]
    
    for test_str in test_cases:
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.char_valid.value = 0
        await Timer(50, units="ns")
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        encoded = encode_cyclic(test_str)
        dut._log.info(f"Test: Input '{test_str}', Encoded '{encoded}'")
        
        dut.start.value = 1
        dut.str_length.value = len(encoded)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        output_chars = []
        for char in encoded:
            dut.char_in.value = ord(char)
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
            dut.char_valid.value = 0
            
            timeout = 0
            while not dut.char_out_valid.value and timeout < 20:
                await RisingEdge(dut.clk)
                timeout += 1
            if dut.char_out_valid.value:
                output_chars.append(chr(int(dut.decoded_char.value)))
        
        for _ in range(10):
            if dut.done.value:
                break
            if dut.char_out_valid.value:
                output_chars.append(chr(int(dut.decoded_char.value)))
            await RisingEdge(dut.clk)
        
        decoded_result = "".join(output_chars)
        dut._log.info(f"Decoded result: '{decoded_result}'")
        assert decoded_result == test_str, f"Expected '{test_str}', got '{decoded_result}'"

@cocotb.test()
async def test_cyclic_decode_randomized(dut):
    """Randomized testing"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    random.seed(42)
    passed = 0
    total = 15
    
    for i in range(total):
        length = random.randint(1, 8)
        test_str = ''.join(random.choice('abcdefgh') for _ in range(length))
        
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.char_valid.value = 0
        await Timer(50, units="ns")
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        encoded = encode_cyclic(test_str)
        
        dut.start.value = 1
        dut.str_length.value = len(encoded)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        output_chars = []
        for char in encoded:
            dut.char_in.value = ord(char)
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
            dut.char_valid.value = 0
            
            timeout = 0
            while not dut.char_out_valid.value and timeout < 30:
                await RisingEdge(dut.clk)
                timeout += 1
            if dut.char_out_valid.value:
                output_chars.append(chr(int(dut.decoded_char.value)))
        
        for _ in range(15):
            if dut.done.value:
                break
            if dut.char_out_valid.value:
                output_chars.append(chr(int(dut.decoded_char.value)))
            await RisingEdge(dut.clk)
        
        decoded_result = "".join(output_chars)
        if decoded_result == test_str:
            passed += 1
        else:
            dut._log.error(f"Random test {i+1} failed: '{test_str}' -> encoded '{encoded}' -> decoded '{decoded_result}'")
    
    dut._log.info(f"
=== SUMMARY ===")
    dut._log.info(f"Randomized tests: {passed}/{total} passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
