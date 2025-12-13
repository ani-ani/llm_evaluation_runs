import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_staircase_solver(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test Case 1: Already matching (0 presses)
    current1 = [0b0001, 0b0011, 0b0110, 0, 0, 0]  # Edges: [0,1],[0,3],[1,2] (M=3)
    desired1 = [0b0001, 0b0011, 0b0110, 0, 0, 0]
    # Test Case 2: Requires 2 presses (R0 then G2)
    current2 = [0b0001, 0b0011, 0b0110, 0b1010, 0, 0]  # Edges [0,1],[0,3],[1,2],[2,4]
    desired2 = [0b0010, 0b0100, 0b1010, 0b1011, 0, 0]  # [0,2],[0,4],[2,3],[2,4]
    # Test Case 3: No solution (max steps reached)
    current3 = [0b0001, 0b0010, 0b0011, 0, 0, 0]  # [0,1],[0,2],[0,3]
    desired3 = [0b0001, 0b0110, 0b1110, 0, 0, 0]  # [0,1],[1,2],[3,2]
    test_cases = [
        (3, current1, desired1, 0, []),
        (4, current2, desired2, 2, [(0,0), (1,2)]),
        (3, current3, desired3, 0, [])
    ]
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    passed = 0
    for tc in test_cases:
        M, curr, des, exp_len, exp_seq = tc
        dut.start.value = 0
        dut.M.value = M
        for i in range(6):
            dut.current_edges[i].value = curr[i]
            dut.desired_edges[i].value = des[i]
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            assert False, "Timeout waiting for done"
        if dut.valid.value == (exp_len > 0):
            if exp_len == 0:
                passed += 1
            else:
                # Verify sequence
                seq_match = True
                for i in range(exp_len):
                    press_type = dut.sequence_type.value >> (3-i) & 0b1
                    floor = (dut.sequence_floor.value >> (2*(15-i))) & 0b11
                    exp_t, exp_f = exp_seq[i]
                    if press_type != exp_t or floor != exp_f:
                        seq_match = False
                if dut.solution_length.value == exp_len and seq_match:
                    passed += 1
                else:
                    dut._log.error(f"Test failed: Expected {exp_len} steps {exp_seq}, got {dut.solution_length.value}")
        else:
            dut._log.error(f"Test failed: valid={dut.valid.value}, expected {exp_len>0}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
