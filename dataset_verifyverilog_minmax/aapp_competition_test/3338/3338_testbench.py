import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_partner_diversity(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 8-bit values)
    test_cases = [
        {  # Original sample equivalent (expect diversity=3)
            "partners": [  # Only first 4 partners used (n=4)
                (78, 61, 88, 71),  # Awakenable
                (80, 80, 90, 90),  # Awakenable
                (70, 90, 80, 100), # Awakenable
                (90, 70, 0, 0)     # Not awakenable
            ],
            "k": 1,
            "expected": 3  # Scaled expectation
        },
        {  # All partners awakenable (expect diversity=2)
            "partners": [
                (50, 70, 80, 80),
                (60, 60, 90, 90),
                (70, 50, 100, 100),
                (50, 50, 70, 70)
            ],
            "k": 3,
            "expected": 2
        }
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        # Apply inputs
        partners = case["partners"]
        dut.partner0_g.value = partners[0][0]
        dut.partner0_p.value = partners[0][1]
        dut.partner0_ga.value = partners[0][2]
        dut.partner0_pa.value = partners[0][3]
        dut.partner1_g.value = partners[1][0]
        dut.partner1_p.value = partners[1][1]
        dut.partner1_ga.value = partners[1][2]
        dut.partner1_pa.value = partners[1][3]
        dut.partner2_g.value = partners[2][0]
        dut.partner2_p.value = partners[2][1]
        dut.partner2_ga.value = partners[2][2]
        dut.partner2_pa.value = partners[2][3]
        dut.partner3_g.value = partners[3][0]
        dut.partner3_p.value = partners[3][1]
        dut.partner3_ga.value = partners[3][2]
        dut.partner3_pa.value = partners[3][3]
        dut.k.value = case["k"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for computation (20 cycles)
        for _ in range(25):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Verify result
        if dut.diversity.value == case["expected"]:
            passed += 1
            dut._log.info(f"Test passed: Expected {case['expected']}, Got {dut.diversity.value}")
        else:
            dut._log.error(f"Test failed: Expected {case['expected']}, Got {dut.diversity.value}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
