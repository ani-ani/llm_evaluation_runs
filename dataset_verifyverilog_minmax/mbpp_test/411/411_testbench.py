import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_snake_to_camel(dut):
    # Test cases (input, expected_output)
    test_cases = [
        # 'android_tv' -> 'AndroidTv'
        (0x616E64726F69645F7476000000000000, 0x416E64726F6964547600000000000000),
        # 'google_pixel' -> 'GooglePixel'
        (0x676F6F676C655F706978656C00000000, 0x476F6F676C65506978656C00000000),
        # 'apple_watch' -> 'AppleWatch'
        (0x6170706C655F77617463680000000000, 0x4170706C6557617463680000000000),
        # Edge case: no underscores
        (0x74657374000000000000000000000000, 0x54657374000000000000000000000000),
        # Edge case: empty string
        (0x00000000000000000000000000000000, 0x00000000000000000000000000000000)
    ]
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    passed = 0
    total = len(test_cases)
    
    for input_data, expected in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input
        dut.data_in.value = input_data
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 16 cycles
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Check output
        if dut.data_out.value == expected:
            passed += 1
            dut._log.info(f"PASS: Input {hex(input_data)} -> {hex(dut.data_out.value)}")
        else:
            dut._log.error(f"FAIL: Input {hex(input_data)}
           Expected {hex(expected)}
           Received {hex(dut.data_out.value)}")
    
    dut._log.info(f"{passed}/{total} tests passed")