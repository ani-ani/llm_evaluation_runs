import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

def pad_list(lst, padding=0xFF):
    return lst + [padding]*(8 - len(lst))

@cocotb.test()
async def test_sorted_merger(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (original sorted and padded to 8 elements)
    test_cases = [
        ( # Test 1
            [4,5,15,24,25,29,110,0xFF],
            [11,19,20,25,56,154,233,0xFF],
            [24,26,48,54,0xFF,0xFF,0xFF,0xFF],
            [4,5,11,15,19,20,24,24,25,25,26,29,48,54,56,110,154,233]
        ),
        ( # Test 2
            [1,3,5,6,8,9,0xFF,0xFF],
            [2,5,7,11,0xFF,0xFF,0xFF,0xFF],
            [1,4,7,8,12,0xFF,0xFF,0xFF],
            [1,1,2,3,4,5,5,6,7,7,8,8,9,11,12]
        )
    ]

    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    for idx, (l1, l2, l3, expected) in enumerate(test_cases):
        # Load inputs
        for i in range(8):
            dut.list1[i].value = l1[i]
            dut.list2[i].value = l2[i]
            dut.list3[i].value = l3[i]

        # Start merge
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (24 cycles)
        await ClockCycles(dut.clk, 24)

        # Verify done signal
        assert dut.done.value == 1, f"Test {idx+1}: Done not asserted after 24 cycles"

        # Collect valid outputs (ignore 0xFF padding)
        result = [dut.merged[i].value for i in range(24) if dut.merged[i].value != 0xFF]

        # Check against expected
        if result == expected:
            passed += 1
            dut._log.info(f"PASS Test {idx+1}: Got {result}")
        else:
            dut._log.error(f"FAIL Test {idx+1}:
  Expected {expected}
  Got      {result}")

        # Reset for next test
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await ClockCycles(dut.clk, 2)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)