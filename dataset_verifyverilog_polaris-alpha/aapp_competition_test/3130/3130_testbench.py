import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_event_deduction(dut):
    # Create 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases: [D, M, imp_pairs, N, init_events, expected_mask]
    test_cases = [
        (3, 2, [(1,2), (2,3)], 1, [2], '111'),   # Original Sample 1
        (3, 2, [(1,3), (2,3)], 1, [3], '001'),   # Original Sample 2
        (4, 4, [(1,2),(1,3),(2,4),(3,4)], 1, [4], '1111')  # Original Sample 3
    ]

    # Run reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for case in test_cases:
        # Load test data
        D, M, imps, N, init_evt, expected = case
        dut.D.value = D-1  # Store D-1 since input is 0-7 for event count
        dut.M.value = M
        dut.N.value = N-1  # Store N-1 (only 0-3 allowed)

        # Load implications (pad unused entries with 0)
        for i in range(16):
            if i < len(imps):
                dut.imp_A[i].value = imps[i][0]-1  # Event IDs to 0-7 index
                dut.imp_B[i].value = imps[i][1]-1
            else:
                dut.imp_A[i].value = 0
                dut.imp_B[i].value = 0

        # Load initial events (pad unused entries with 0)
        for i in range(4):
            if i < len(init_evt):
                dut.init_evts[i].value = init_evt[i]-1  # 0-7 index
            else:
                dut.init_evts[i].value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 40 cycles)
        for _ in range(40):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done signal"

        # Verify result
        expected_int = int(expected, 2)
        result_str = ''.join(['1' if bit else '0' for bit in dut.result.value])
        if dut.result.value == expected_int:
            passed += 1
        else:
            dut._log.error(f"Test failed:
  Inputs: D={D}, M={M}, imps={imps}, N={N}, init={init_evt}
  Expected: {expected} (binary)
  Got:      {dut.result.value.binstr}")
        await RisingEdge(dut.clk)

    # Summary
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)