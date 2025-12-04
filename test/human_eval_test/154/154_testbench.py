import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def str_to_bits(s, length=8):
    # Convert string to 64-bit ASCII value with null padding
    bytes_list = s.encode()[:length]
    padded = bytes_list + b'\0'*(length - len(bytes_list))
    return int.from_bytes(padded, byteorder='big')

@cocotb.test()
async def test_cycpattern(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Define test cases (original adapted to 8-byte limit)
    test_cases = [
        ("xyzw    ", 4, "xyw     ", 3, False),  # test #0
        ("yello   ", 5, "ell     ", 3, True),   # test #1
        ("whattup ", 7, "ptut    ", 4, False),  # test #2
        ("efef    ", 4, "fee     ", 3, True),   # test #3
        ("abab    ", 4, "aabb    ", 4, False),  # test #4
        ("winemtt ", 7, "tinem   ", 5, True)    # test #5
    ]

    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for a, len_a, b, len_b, expected in test_cases:
        # Prepare inputs
        dut.str_a.value = str_to_bits(a)
        dut.pattern_b.value = str_to_bits(b)
        dut.len_a.value = len_a
        dut.len_b.value = len_b
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 8 cycles)
        cycle_count = 0
        while not dut.done.value and cycle_count < 10:
            await RisingEdge(dut.clk)
            cycle_count += 1
        
        # Check result
        if cycle_count >= 10:
            dut._log.error(f"Timeout on test: {a}|{b}")
            continue
            
        if dut.found.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{a.strip()}'/{len_a} vs '{b.strip()}'/{len_b} => {expected}")
        else:
            dut._log.error(f"FAIL: '{a.strip()}'/{len_a} vs '{b.strip()}'/{len_b} => {dut.found.value} (expected {expected})")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"