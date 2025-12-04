import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import array

@cocotb.test()
async def test_string_factoring(dut):
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Test cases (input string, expected weight)
    test_cases = [
        ("PRATTATTATTIC", 6),  # Length 13
        ("GGGGGGGGG", 1),      # Length 9
        ("PRIME", 5),          # Length 5
        ("BABBABABBABBA", 6), # Length 13
        ("ARPARPARPARPAR", 5) # Length 13
    ]

    # Initialize and reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    total = len(test_cases)

    for s, expected in test_cases:
        # Load string data (pad to 16 chars with zeros)
        dut.length.value = len(s)
        for i in range(16):
            dut.chars[i].value = ord(s[i]) if i < len(s) else 0

        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 256 cycles)
        for _ in range(256):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Check result
        if dut.weight.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed for '{s}': Got {dut.weight.value}, expected {expected}")
        await Timer(10, units="ns")

    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total