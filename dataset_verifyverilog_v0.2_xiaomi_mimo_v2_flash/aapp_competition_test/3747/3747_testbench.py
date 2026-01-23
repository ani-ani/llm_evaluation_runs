import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_bulbasaur_counter(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_input.value = 0
    dut.str_len.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (string, expected_result)
        ("Bulbbasaur", 1),
        ("F", 0),
        ("aBddulbasaurrgndgbualdBdsagaurrgndbb", 2),
        ("Bulbasaur", 1),
        ("BulbasaurBulbasaur", 2),
        ("BBBuuuulllbbbaaasssaaauuurrr", 3),
        ("BBBBBBBBBBbbbbbbbbbbuuuuuuuuuullllllllllssssssssssaaaaaaaaaarrrrrrrrrr", 5),
        ("Bbulsar", 0),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for string, expected in test_cases:
        # Pack string into 128-bit value
        str_bytes = string.encode('ascii')
        packed = 0
        for i, byte in enumerate(str_bytes):
            packed |= byte << (8 * i)
        
        dut.str_input.value = packed
        dut.str_len.value = len(str_bytes)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 20 cycles + some margin)
        timeout = 30
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            print(f"PASS: '{string}' -> {actual}")
        else:
            print(f"FAIL: '{string}' -> Expected {expected}, got {actual}")
    
    print(f"{passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
