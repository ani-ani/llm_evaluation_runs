import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct

def str_to_bits(s):
    # Pad to 16 chars with null bytes
    s_padded = s.ljust(16, '\0')[:16]
    # Pack into 128-bit value (big-endian: first char at [127:120])
    return struct.unpack('>Q', bytes(s_padded.encode('ascii')))[0] << 64 | struct.unpack('>Q', bytes(s_padded.encode('ascii')))[1]

@cocotb.test()
async def test_paren_depth(dut):
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_groups = [
        # Format: (input_string, expected_depth)
        ("(()()) \0\0\0\0\0\0\0\0\0\0", 2),
        ("((())) \0\0\0\0\0\0\0\0\0\0", 3),
        ("()      \0\0\0\0\0\0\0\0\0", 1),
        ("(()(())((())))", 4),
        ("((((()))))\0\0\0\0\0", 5)
    ]

    # Reset first
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for i, (test_str, expected) in enumerate(test_groups):
        # Load string input
        dut.group_string.value = str_to_bits(test_str)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 16 cycles for processing
        for _ in range(16):
            await RisingEdge(dut.clk)

        # Check result
        if dut.done.value == 1:
            result = dut.max_depth.value.integer
            if result == expected:
                dut._log.info(f"Test {i} PASS: '{test_str}' → {result}")
                passed += 1
            else:
                dut._log.error(f"Test {i} FAIL: '{test_str}' got {result}, expected {expected}")
        else:
            dut._log.error(f"Test {i} FAIL: done signal not asserted")
        
        # Insert pause between tests
        await Timer(20, units='ns')
    
    dut._log.info(f"{passed}/{len(test_groups)} tests passed")