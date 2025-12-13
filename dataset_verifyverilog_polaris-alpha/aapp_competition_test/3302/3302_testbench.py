import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_verifier(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Valid 3-bit Gray code (P={1})
    n = 3
    palette = 0b0010 # Bitmask for {1}
    sequence = [
        0b000, 0b001, 0b011, 0b010, 0b110, 0b111, 0b101, 0b100,
        0,0,0,0,0,0,0,0 # pad to 16 elements
    ]
    test_case = (n, 1, palette, sequence, 1)
    await run_verification(dut, test_case)

    # Test Case 2: Invalid n=2 P={2}
    n = 2
    palette = 0b1000 # Bitmask for {2}
    sequence = [0b00, 0b11, 0b01, 0b10, 0,0,0,0,0,0,0,0,0,0,0,0]
    test_case = (n, 2, palette, sequence, 0)
    await run_verification(dut, test_case)

    # Test Case 3: Valid P={2,1} (Mixed distances)
    n = 2
    palette = 0b1010 # Bitmask for {1,2}
    sequence = [0b00, 0b11, 0b01, 0b10, 0,0,0,0,0,0,0,0,0,0,0,0]
    test_case = (n, 2, palette, sequence, 1)
    await run_verification(dut, test_case)

async def run_verification(dut, test_case):
    n, p, palette, sequence, expected = test_case
    dut.n.value = n
    dut.p.value = p
    dut.palette.value = palette
    for i in range(16):
        dut.sequence_in[i].value = sequence[i] if i < (2**n) else 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        dut._log.error("Verification didn't complete")
    else:
        assert dut.valid.value == expected, f"Expected {expected} got {dut.valid.value}"
