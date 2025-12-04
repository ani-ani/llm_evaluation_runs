import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def str_to_ascii(s):
    return [ord(c) for c in s.ljust(16)]

@cocotb.test()
async def test_tuple_parser(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        ("(7, 8, 9)        ", (7, 8, 9)),
        ("(1, 2, 3)        ", (1, 2, 3)),
        ("(4, 5, 6)        ", (4, 5, 6)),
        ("(7, 81, 19)       ", (7, 81, 19)),
        ("(100,999,255)     ", (100, 999, 255))
    ]
    
    passed = 0
    total = len(test_cases)
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for case in test_cases:
        input_str, expected = case
        
        # Convert string to 16-byte array
        ascii_bytes = str_to_ascii(input_str)
        for i, byte in enumerate(ascii_bytes):
            dut.str_in[i].value = byte
            
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 3 cycles for processing
        for _ in range(3):
            await RisingEdge(dut.clk)
        
        # Capture outputs
        result = (dut.num1.value, dut.num2.value, dut.num3.value)
        
        # Check outputs
        if (int(dut.num1.value) == expected[0] and 
            int(dut.num2.value) == expected[1] and 
            int(dut.num3.value) == expected[2] and
            int(dut.done.value) == 1):
            passed += 1
            dut._log.info(f"PASS: {input_str} -> {result}")
        else:
            dut._log.error(f"FAIL: {input_str} -> {result}, expected {expected}")
        
        await RisingEdge(dut.clk)  # Wait for done to clear
        
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total