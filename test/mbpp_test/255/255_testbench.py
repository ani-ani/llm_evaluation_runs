import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_combo_gen(dut):
    # Color encodings
    RED = 0
    GREEN = 1
    BLUE = 2

    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)

    def encode_combo(elements):
        """Encode tuple of string colors to packed bits"""
        mapping = {"Red": RED, "Green": GREEN, "Blue": BLUE}
        encoded = 0
        for i, color in enumerate(elements):
            encoded |= mapping[color] << (2*i)
        return encoded

    test_cases = [
        {"colors": ["Red", "Green", "Blue"], "n": 1, "expected": [(RED,),(GREEN,),(BLUE,)]},
        {"colors": ["Red", "Green", "Blue"], "n": 2, "expected": [(RED,RED), (RED,GREEN), (RED,BLUE), (GREEN,GREEN), (GREEN,BLUE), (BLUE,BLUE)]},
        {"colors": ["Red", "Green", "Blue"], "n": 3, "expected": [(RED,RED,RED), (RED,RED,GREEN), (RED,RED,BLUE), (RED,GREEN,GREEN), (RED,GREEN,BLUE), (RED,BLUE,BLUE), (GREEN,GREEN,GREEN), (GREEN,GREEN,BLUE), (GREEN,BLUE,BLUE), (BLUE,BLUE,BLUE)]}
    ]
    
    passed = 0
    await reset()

    for case in test_cases:
        # DUT expects encoded value in current_combo output
        expected_encoded = [encode_combo([color]*len(combo)) if len(combo)==1 else encode_combo(combo) for combo in case["expected"]]
        
        dut._log.info(f"Testing combo_len={case['n']}")
        dut.combo_len.value = case['n'] - 1  # Input is 0-based: 0→len1, 1→len2, 2→len3
        await RisingEdge(dut.clk)
        
        # Start generation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        results = []
        timeout = 0
        max_wait = 2*len(case['expected']) + 5
        
        while not dut.done.value and timeout < max_wait:
            if dut.combo_count.value > 0 and dut.current_combo.value != 0:
                results.append(int(dut.current_combo.value))
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Verify all combinations
        match_count = 0
        for exp in expected_encoded:
            if exp in results:
                match_count += 1
            else:
                dut._log.error(f"Missing combination: {exp}")
        
        # Verify final count
        if dut.combo_count.value == len(case['expected']) and 
           match_count == len(case['expected']) and 
           len(results) == len(case['expected']):
            passed += 1
            dut._log.info(f"PASSED len={case['n']}")
        else:
            dut._log.error(f"FAIL len={case['n']} Got {len(results)} combos but expected {len(case['expected'])}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)