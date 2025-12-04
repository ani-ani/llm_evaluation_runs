import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import itertools

@cocotb.test()
async def test_encoder(dut):
    # Generate 100MHz clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Test cases (16-byte padded with nulls)
    test_cases = [
        (b'TEST\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00', b'tgst\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'),
        (b'Mudasir\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00', b'mWDCSKR\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'),
        (b'YES\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00', b'ygs\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'),
        (b'This is a message', b'tHKS KS C MGSSCGG')
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
    
    for input_str, expected in test_cases:
        # Apply test case
        for i in range(16):
            if i < len(input_str):
                dut.data_in[i].value = input_str[i]
            else:
                dut.data_in[i].value = 0
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        result = bytes([dut.data_out[i].value for i in range(16)])
        expected_padded = expected.ljust(16, b'\x00')
        
        if result == expected_padded:
            passed += 1
            dut._log.info(f"PASS: {input_str} -> {expected}")
        else:
            dut._log.error(f"FAIL: {input_str} -> {result}, expected {expected_padded}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
