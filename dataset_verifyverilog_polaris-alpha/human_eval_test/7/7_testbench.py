import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_filter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper to pack strings
    def pack_string(s):
        s += '\\0' * (8 - len(s))
        return int.from_bytes(s.encode(), 'big')
    
    # Test cases adapted to 8-byte/3-substring limits
    test_cases = [
        # TC1: Empty list
        {'num': 0, 'strings': [], 'sub': 'joh', 'len': 3, 'expected': 0},
        # TC2: ['xxx','asd','xxy','john doe','xxxAAA','xxx'] -> indices 0,4,5
        {'num': 6,
         'strings': ['xxx', 'asd', 'xxy', 'john doe', 'xxxAAA', 'xxx'],
         'sub': 'xxx', 'len': 3,
         'expected': 0b00110001},
        # TC3: Original 'xx' test -> indices 0,2,4,5
        {'num': 6,
         'strings': ['xxx', 'asd', 'aaaxxy', 'john doe', 'xxxAAA', 'xxx'],
         'sub': 'xx', 'len': 2,
         'expected': 0b00110101},
        # TC4: ['grunt','prune'] (indices 0,2)
        {'num': 4,
         'strings': ['grunt', 'trumpet', 'prune', 'gruesome'],
         'sub': 'run', 'len': 3,
         'expected': 0b00000101}
    ]
    
    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Pack strings
        strings_val = 0
        for i, s in enumerate(case['strings']):
            packed = pack_string(s)
            strings_val |= packed << (64 * (7-i))  # MSB has string0 for easier debug
        dut.strings_packed.value = strings_val
        
        # Set controls
        dut.substring.value = int.from_bytes(case['sub'][:3].encode(), 'big')
        dut.substring_len.value = case['len']
        dut.num_strings.value = case['num']
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 8 cycles
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Check results
        if dut.match_mask.value == case['expected']:
            passed += 1
            dut._log.info(f"PASS: Mask {bin(dut.match_mask.value)} == expected {bin(case['expected'])}")
        else:
            dut._log.error(f"FAIL: Mask {bin(dut.match_mask.value)} != expected {bin(case['expected'])}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)