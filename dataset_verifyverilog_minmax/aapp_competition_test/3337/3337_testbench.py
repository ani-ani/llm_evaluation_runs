import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_stack_ops(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.cmd_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    test_vectors = [
        # (op_type, v, w, expected_result, has_output)
        (0, 0, 0, None, False),  # Step1: 'a 0' (push)
        (0, 1, 0, None, False),  # Step2: 'a 1' (push)
        (1, 2, 0, 2, True),     # Step3: 'b 2' (pop)
        (2, 2, 3, 1, True),     # Step4: 'c 2 3' (count)
        (1, 4, 0, 2, True)      # Step5: 'b 4' (pop)
    ]
    # Pad remaining steps with no-ops
    test_vectors += [(0,0,0,None,False)] * 11
    outputs = []
    passed = 0

    for step, (op, v_val, w_val, exp, exp_valid) in enumerate(test_vectors):
        dut.cmd_valid.value = 1
        dut.op_type.value = op
        dut.v.value = v_val
        dut.w.value = w_val
        await RisingEdge(dut.clk)
        dut.cmd_valid.value = 0
        await RisingEdge(dut.clk)
        if exp_valid:
            if dut.result_valid.value != 1:
                dut._log.error("Result_valid not asserted at step %d", step+1)
            result = dut.result.value.integer
            outputs.append(result)
            if result == exp:
                passed += 1
            else:
                dut._log.error("Mismatch at step %d: got %d, expected %d", step+1, result, exp)
        await Timer(1, 'ns')
    expected = [2, 1, 2]
    dut._log.info(f"{passed}/{len(expected)} tests passed")
    assert outputs == expected, "Output sequence mismatch"