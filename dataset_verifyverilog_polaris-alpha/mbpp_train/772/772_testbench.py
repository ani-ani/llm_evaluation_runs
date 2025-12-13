import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_word_filter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Custom ASCII conversion helper
    def str_to_bin(s):
        bin_str = 0
        for i, char in enumerate(s.ljust(32)[:32]):
            bin_str |= ord(char) << (8*i)
        return bin_str
    
    def bin_to_str(b):
        chars = []
        for i in range(32):
            chars.append(chr((b >> (8*i)) & 0xFF))
        return ''.join(chars).rstrip('\\x00').rstrip()
    
    test_cases = [
        ("The person most value  ", 3, "person most value"),
        ("You me ok           ", 2, "You me ok"),
        ("Danger darkeness     ", 4, "Danger"),
        ("A B C D E         ", 1, "B C D E")
    ]

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for i, (input_str, k, expected) in enumerate(test_cases):
        dut._log.info(f"Testing case {i+1}: '{input_str}' K={k}")
        
        # Prepare inputs
        dut.start.value = 0
        dut.str_in.value = str_to_bin(input_str)
        dut.K.value = k
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify outputs
        result_str = bin_to_str(dut.str_out.value).strip()
        assert result_str == expected, f"Case {i+1} failed: Got '{result_str}', expected '{expected}'"
        dut._log.info(f"PASS {i+1}: Input '{input_str.strip()}' K={k} => '{result_str}'")
    
    dut._log.info(f"{len(test_cases)}/{len(test_cases)} tests passed")