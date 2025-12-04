import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_last_char_checker(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    test_cases = [
        ("apple           ", 0),  # Original: "apple" -> False
        ("apple pi e      ", 1),  # "apple pi e" -> True
        ("A              ", 1),  # "A" -> True
        ("Pumpkin pie   ", 0),   # "Pumpkin pie " -> False
        ("" + '\0'*15,       0),  # Empty string
        ("e             ", 0),  # Single char not meeting criteria
        ("word a        ", 1)   # Last char 'a' after space
    ]
    
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for txt, expected in test_cases:
        # Convert string to ASCII bytes
        txt_bytes = [ord(c) for c in txt]
        for i in range(16):
            dut.txt[i].value = txt_bytes[i]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {txt} -> {expected}")
        else:
            dut._log.error(f"FAIL: {txt} -> {dut.result.value}, expected {expected}")
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")