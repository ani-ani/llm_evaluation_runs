import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_quote_extractor(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (bytes(b'"Python", "PHP", "Java"\0          '), [b'Python', b'PHP', b'Java']),
        (bytes(b'"python","program","language"\0   '), [b'python', b'program', b'language']),
        (bytes(b'"red","blue","green","yellow"\0 '), [b'red', b'blue', b'green', b'yellow']),
        (bytes(b'"single_string"\0                    '), [b'single_string']),
        (bytes(b'no_quotes_here\0                      '), [])
    ]
    
    passed = 0
    for text_input, expected in test_cases:
        # Wait for ready state
        await RisingEdge(dut.clk)
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Setup input
        for i in range(64):
            dut.text_input[i].value = text_input[i] if i < len(text_input) else 0
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Verify outputs
        correct = True
        if dut.string_count.value != len(expected):
            correct = False
            dut._log.error(f"String count mismatch: {dut.string_count.value} vs {len(expected)}")
        else:
            for i in range(len(expected)):
                s = b''
                for j in range(16):
                    char_val = dut.extracted_strings[i][j].value
                    if char_val != 0:
                        s += bytes([char_val])
                if s != expected[i]:
                    correct = False
                    dut._log.error(f"Mismatch at string {i}: {s} vs {expected[i]}")
                    break
            
            # Verify unused slots are empty
            for i in range(len(expected), 8):
                if dut.extracted_strings[i][0].value != 0:
                    correct = False
                    dut._log.error(f"Non-empty slot {i} found")
                    break
        
        if correct:
            passed += 1
            dut._log.info(f"PASS: {text_input}")
        else:
            dut._log.error(f"FAIL: {text_input}")
        
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"