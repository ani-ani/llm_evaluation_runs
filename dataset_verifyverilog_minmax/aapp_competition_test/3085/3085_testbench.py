import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_bracket(dut):
    clock = Clock(dut.clk, 10, units="ns") 
    cocotb.start_soon(clock.start())
    test_cases = [
        ("(())    ", "4,8:8,8:           "),  # 8-char padded input
        ("()      ", "4,4:             "),
        ("((()))  ", "5,17:11,17:17,17:     ")
    ]
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    passed = 0
    total = len(test_cases)

    for input_str, expected in test_cases:
        # Encode input (ascii not needed in this simplified version)
        encoded = 0
        for i, c in enumerate(input_str.strip()):
            if c == '(':
                encoded |= 1 << (7 - i)
        dut.input_str.value = encoded
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Wait for completion (max 16 cycles)
        for _ in range(20): 
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            assert False, "Timeout waiting for done"

        # Convert output buffer to string
        output_bytes = [chr((dut.output_buf.value >> (8*i)) & 0xff) for i in range(64)]
        result_str = ''.join(output_bytes[:dut.output_len.value]).strip()
        # Compare with expected (strip trailing spaces)
        expected_clean = expected.strip()
        if result_str == expected_clean:
            passed += 1
        else:
            dut._log.error(f"Failed on input '{input_str}': Got '{result_str}', Expected '{expected_clean}'")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total