import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def str_to_bytes(s):
    return [ord(c) for c in s.ljust(8, '\\0')]

@cocotb.test()
async def test_decimal_checker(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ('123.11', 1),
        ('e666.86', 0),
        ('3.1245', 0),  # Original had 7 chars, shortened to 6
        ('1.11', 1),
        ('1.1.11', 0),
        ('12345678', 1),  # Max length integer
        ('12.34', 1),     # Exact 2 decimals
        ('12.3', 1),      # Single decimal allowed
        ('12.', 0),       # Missing decimals
        ('.99', 0),       # Missing integer
        ('0.0', 1),       # Valid zero
        ('12a.34', 0),    # Invalid character
    ]
    
    passed = 0
    for input_str, expected in test_cases:
        # Setup test
        dut.start.value = 1
        bytes_in = str_to_bytes(input_str)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send characters
        for i, byte_val in enumerate(bytes_in):
            dut.char_in.value = byte_val
            dut.last_char.value = 1 if i == len(input_str)-1 else 0
            await RisingEdge(dut.clk)
            dut.last_char.value = 0
        
        # Wait for result (1 clk after last char)
        await RisingEdge(dut.clk)
        
        # Check outputs
        if dut.valid.value == expected and dut.done.value == 1:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> {expected}")
        else:
            dut._log.error(f"FAIL: '{input_str}' -> {dut.valid.value} (expected {expected})")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")