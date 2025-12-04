import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_filter(dut):
    # Define test cases (original converted to 64-char max)
    test_cases = [
        # (string, target, expected_mask)
        ("Mary had a little lamb        ", 4, 0b00010000),  # 'little' at index 3
        ("Mary had a little lamb        ", 3, 0b10000001),  # Mary(index0), lamb(index6)
        ("simple white space            ", 2, 0b00000000),
        ("Hello world                   ", 4, 0b00000010),  # 'world' index1
        ("Uncle sam                     ", 3, 0b00000001),  # 'Uncle' index0
        ("", 4, 0b00000000),
        ("a b c d e f                   ", 1, 0b01111100)   # 'b','c','d','f' => bits2-5 set
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    for i, (s, n, expected) in enumerate(test_cases):
        # Convert string to packed 64-byte format
        s_padded = s.ljust(64)
        s_bin = int.from_bytes(s_padded.encode('ascii'), 'big')
        
        # Reset & initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Feed inputs
        dut.string_data.value = s_bin
        dut.target_count.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (max 64 cycles)
        for _ in range(66):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Verify output
        mask = dut.matched_words.value
        if mask == expected:
            passed += 1
            dut._log.info(f"PASS {i}: {s.strip()}
- Expected: {bin(expected)}, Got: {bin(mask)}")
        else:
            dut._log.error(f"FAIL {i}: {s.strip()} (n={n})
- Expected: {bin(expected)}, Got: {bin(mask)}")
    
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")