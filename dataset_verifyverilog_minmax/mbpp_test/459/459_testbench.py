import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import binascii

async def apply_reset(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def str_to_bits(s):
    padded = s.ljust(16, '\\0')
    return int.from_bytes(padded.encode(), 'big')

def filter_uppercase(s):
    return ''.join(c for c in s if not ('A' <= c <= 'Z'))

@cocotb.test()
async def test_remove_uppercase(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Test cases (truncated to 16 chars)
    test_cases = [
        ('cAstyoUrFavoRitE', 'cstyoravoit'),  # Original: 'cAstyoUrFavoRitETVshoWs'
        ('wAtchTheinTernE', 'wtchheinernt'),   # Original: 'wAtchTheinTernEtrAdIo'
        ('VoicESeaRchAnd', 'oiceachnd'),       # Original: 'VoicESeaRchAndreComMendaTionS'
        ('AbCdEfGhIjKlMn', ''),                # All uppercase
        ('123aB!c#D$e%F^', '123a!c#e%^')       # Mixed chars
    ]
    
    await apply_reset(dut)
    passed = 0
    
    for input_str, expected in test_cases:
        # Pad input to 16 characters
        input_padded = input_str.ljust(16, '\\0')
        expected_padded = expected.ljust(16, '\\0')[:len(expected)]
        
        # Apply input
        dut.str_in.value = str_to_bits(input_padded)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 16 cycles
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Check output
        out_bytes = dut.str_out.value.buff_to_bytes()
        out_str = out_bytes.decode().rstrip('\\x00')
        out_len = dut.out_length.value
        
        dut._log.info(f"Input: '{input_str}' => Output: '{out_str}' (expected: '{expected}')")
        
        if out_str == expected and out_len == len(expected):
            passed += 1
            dut._log.info("PASS")
        else:
            dut._log.error(f"FAIL: Got '{out_str}' (len {out_len}), expected '{expected}' (len {len(expected)})")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)