import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_typo_checker(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())  
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    # Test words: ["close", "lose", "he", "the"] (simplified from sample 1)
    words = [bytes(w.ljust(8), 'utf-8') for w in ["close", "lose", "he", "the"]]
    expected_matches = [
        (0,1,1), # close-lose
        (1,2,0), # lose-he
        (2,3,1)  # he-the
    ]
    
    # Feed input characters
    dut.start.value = 1
    for word in words:
        for i in range(8):
            dut.char_in.value = word[i]
            await RisingEdge(dut.clk)
        dut.word_end.value = 1
        await RisingEdge(dut.clk)
        dut.word_end.value = 0
    
    # End marker
    dut.char_in.value = 0
    dut.word_end.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.word_end.value = 0
    
    # Wait for processing
    await ClockCycles(dut.clk, 16)
    
    # Check results
    errors = 0
    for i,j,exp in expected_matches:
        actual = dut.matches[i][j].value
        if actual != exp:
            dut._log.error(f"Match [{i}][{j}] expected {exp} got {actual}")
            errors += 1
    
    if errors == 0:
        dut._log.info("4/4 expected matches verified")
    else:
        dut._log.error(f"{errors}/4 matches incorrect")
    
    assert errors == 0, "Mismatch detected between expected and actual results"