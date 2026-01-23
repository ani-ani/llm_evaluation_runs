import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

# Helper to pack string to fixed width bytes
def pack_word(word):
    b = bytes(word, 'ascii')
    if len(b) > 8:
        raise ValueError(f"Word {word} too long")
    padded = b.ljust(8, b'\x00')
    val = 0
    for i, byte in enumerate(padded):
        val |= byte << (i * 8)
    return val

@cocotb.test()
async def test_typo_detector(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.in_valid.value = 0
    dut.in_is_last.value = 0
    dut.in_word.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Dictionary {hoose, hose, nose, noises, noise}
    # Expected Typos: hoose (->hose), noises (->noise), noise (->nose)
    
    words = ["hoose", "hose", "nose", "noises", "noise"]
    expected_typos = {"hoose", "noises", "noise"}
    found_typos = []

    # Feed words
    dut._log.info("Starting Test Case 1")
    for i, word in enumerate(words):
        dut.in_word.value = pack_word(word)
        dut.in_valid.value = 1
        dut.in_is_last.value = 1 if i == len(words) - 1 else 0
        await RisingEdge(dut.clk)
        
        # Wait for potential output (if word is a typo, output should appear shortly after load/check)
        # The module design processes check after load. 
        # We will loop to catch outputs.
    
    dut.in_valid.value = 0
    
    # Collect outputs for a few cycles
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.out_valid.value:
            # Decode word
            val = dut.out_word.value
            b = [(val >> (i*8)) & 0xFF for i in range(8)]
            w = bytes(b).rstrip(b'\x00').decode('ascii')
            found_typos.append(w)
            dut._log.info(f"Detected typo: {w}")
        if dut.done.value:
            break

    # Verify Test Case 1
    missing = expected_typos - set(found_typos)
    extra = set(found_typos) - expected_typos
    if missing:
        raise TestFailure(f"Missing typos: {missing}")
    if extra:
        raise TestFailure(f"Unexpected typos: {extra}")
    
    dut._log.info("Test Case 1 Passed")

    # Reset for Test Case 2
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Dictionary {hose, hoose, oose, moose}
    # Expected Typos: hoose (->hose), moose (->oose)
    words2 = ["hose", "hoose", "oose", "moose"]
    expected_typos2 = {"hoose", "moose"}
    found_typos2 = []

    dut._log.info("Starting Test Case 2")
    for i, word in enumerate(words2):
        dut.in_word.value = pack_word(word)
        dut.in_valid.value = 1
        dut.in_is_last.value = 1 if i == len(words2) - 1 else 0
        await RisingEdge(dut.clk)
    
    dut.in_valid.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.out_valid.value:
            val = dut.out_word.value
            b = [(val >> (i*8)) & 0xFF for i in range(8)]
            w = bytes(b).rstrip(b'\x00').decode('ascii')
            found_typos2.append(w)
            dut._log.info(f"Detected typo: {w}")
        if dut.done.value:
            break

    missing2 = expected_typos2 - set(found_typos2)
    extra2 = set(found_typos2) - expected_typos2
    if missing2:
        raise TestFailure(f"Missing typos: {missing2}")
    if extra2:
        raise TestFailure(f"Unexpected typos: {extra2}")

    dut._log.info("Test Case 2 Passed")
    
    # Test Case 3: No Typos
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    words3 = ["apple", "pear"]
    dut._log.info("Starting Test Case 3 (No Typos)")
    for i, word in enumerate(words3):
        dut.in_word.value = pack_word(word)
        dut.in_valid.value = 1
        dut.in_is_last.value = 1 if i == len(words3) - 1 else 0
        await RisingEdge(dut.clk)
    
    dut.in_valid.value = 0
    found_typos3 = []
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.out_valid.value:
            val = dut.out_word.value
            b = [(val >> (i*8)) & 0xFF for i in range(8)]
            w = bytes(b).rstrip(b'\x00').decode('ascii')
            found_typos3.append(w)
        if dut.done.value:
            break
            
    if found_typos3:
        raise TestFailure(f"Unexpected typos found: {found_typos3}")
    
    dut._log.info("Test Case 3 Passed")
    dut._log.info("All tests passed!")
