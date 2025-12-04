import cocotb
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb.clock import Clock

@cocotb.test()
async def sublist_sorter_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Test 1
        {
            'input': [[b"green  ", b"orange "], [b"black  ", b"white  "], [b"white  ", b"black  ", b"orange "], [b"", b"", b"", b""]],
            'sizes': [2,2,3,0],
            'expected': [[b"green  ", b"orange ", b"", b""],
                         [b"black  ", b"white  ", b"", b""],
                         [b"black  ", b"orange ", b"white  ", b""],
                         [b"", b"", b"", b""]]
        },
        # Test 2
        {
            'input': [[b" red   ", b"green  "], [b"blue   ", b" black "], [b" orange", b"brown  "], [b"", b"", b"", b""]],
            'sizes': [2,2,2,0],
            'expected': [[b"green  ", b" red   ", b"", b""],
                         [b" black ", b"blue   ", b"", b""],
                         [b"brown  ", b" orange", b"", b""],
                         [b"", b"", b"", b""]]
        }
    ]

    passed = 0
    for i, tc in enumerate(test_cases):
        dut.start.value = 0
        # Flatten test data
        for list_idx in range(4):
            for word_idx in range(4):
                val = 0
                for char_idx, char in enumerate(tc['input'][list_idx][word_idx] if word_idx<len(tc['input'][list_idx]) else b" "*8):
                    val |= char << (8 * (7-char_idx))
                dut.data_in[list_idx][word_idx].value = val
            dut.sizes_in[list_idx].value = tc['sizes'][list_idx]

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify outputs
        correct = True
        for list_idx in range(4):
            for word_idx in range(4):
                expected_val = 0
                expected_str = tc['expected'][list_idx][word_idx]
                for char_idx, char in enumerate(expected_str.ljust(8)):
                    expected_val |= char << (8*(7-char_idx))
                
                if dut.data_out[list_idx][word_idx].value != expected_val:
                    dut._log.error(f"Test {i} List {list_idx} Word {word_idx}: Got %s, Expected %s",
                                 bytes.fromhex(f"{dut.data_out[list_idx][word_idx].value.integer:016x}").decode('utf-8').strip(),
                                 expected_str.decode('utf-8').strip())
                    correct = False

        if correct:
            passed += 1
            dut._log.info(f"Test {i} PASSED")
        else:
            dut._log.error(f"Test {i} FAILED")

        await ClockCycles(dut.clk, 2)  # Inter-test gap

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")