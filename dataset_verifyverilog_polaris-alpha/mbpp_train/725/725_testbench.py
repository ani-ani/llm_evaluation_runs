import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_quote_extractor(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Input (padded to 16 chars),        Expected Results                 Expected Valid
        (b'"A53" multi  ""',              b'A53\x00\x00\x00\x00\x00multi\x00', 0b11),
        (b'"favor" apps  ',               b'favor\x00\x00\x00app\x00\x00\x00',0b10),
        (b'"4k Ultra""HDR"     ',         b'4k UltrHDR\x00\x00\x00\x00',     0b11),
        (b'No quotes here    ',            b'\x00'*16,                        0b00),
        (b'Partial"quote only',            b'quote on\x00\x00\x00\x00\x00',   0b10)
    ]
    
    passed = 0
    for idx, (text_in, expected, exp_valid) in enumerate(test_cases):
        # Set input
        dut.text.value = int.from_bytes(text_in, 'big')
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 17 cycles for processing
        for _ in range(17):
            await RisingEdge(dut.clk)
        
        # Check results
        results = dut.results.value.buff
        valid = dut.valid.value
        
        try:
            assert valid == exp_valid, f"Test {idx} valid mismatch: {valid} vs {exp_valid}"
            assert results == expected, f"Test {idx} output mismatch"
            passed += 1
            dut._log.info(f"Test {idx} PASS")
        except AssertionError as e:
            dut._log.error(f"Test {idx} FAIL
{' '.join(f'{b:08b}' for b in results)}
"
                          f"{' '.join(f'{b:08b}' for b in expected)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
