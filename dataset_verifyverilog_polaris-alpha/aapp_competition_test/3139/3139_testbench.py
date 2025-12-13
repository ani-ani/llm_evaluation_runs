import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_student_helper(dut):
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_case_1 = [
        ('D', 0, 3, 1, None),    # Student 1
        ('D', 1, 2, 2, None),    # Student 2
        ('D', 2, 1, 3, None),    # Student 3
        ('P', 0, None, None, 0), # Query 1=p0:NE
        ('P', 1, None, None, 0), # Query 2=p1:NE
        ('P', 2, None, None, 0)  # Query 3=p2:NE
    ]

    test_case_2 = [
        ('D', 0, 8, 8, None),    # Student 1
        ('D', 1, 2, 4, None),    # Student 2
        ('D', 2, 5, 6, None),    # Student 3
        ('P', 1, None, None, 3), # Query 2=p1→3
        ('D', 3, 6, 2, None),    # Student 4
        ('P', 3, None, None, 1)  # Query 4=p3→1
    ]

    test_case_3 = [
        ('D', 0, 5, 2, None),    # Student 1
        ('D', 1, 5, 3, None),    # Student 2
        ('P', 0, None, None, 2), # Query 1=p0→2
        ('D', 2, 7, 1, None),    # Student 3
        ('D', 3, 8, 7, None),    # Student 4
        ('P', 2, None, None, 4), # Query 3=p2→4
        ('P', 1, None, None, 4)  # Query 2=p1→4
    ]

    passed = 0
    total_commands = 0

    for test_case in [test_case_1, test_case_2, test_case_3]:
        for (cmd, idx, a_val, b_val, expected) in test_case:
            dut.cmd.value = 0 if cmd == 'D' else 1
            dut.student_id.value = idx

            if cmd == 'D':
                dut.A_in.value = a_val
                dut.B_in.value = b_val
                await RisingEdge(dut.clk)
                total_commands += 1
            else:
                dut.A_in.value = 0
                dut.B_in.value = 0
                await Timer(1, 'ns')  # Combinational settle
                if dut.result_valid.value != 1:
                    dut._log.error("result_valid not asserted")
                if int(dut.result_id.value) == expected:
                    passed += 1
                else:
                    dut._log.error(f"Failed: For P{idx+1} got {dut.result_id.value} != {expected}")
                total_commands += 1
                await RisingEdge(dut.clk)

    dut._log.info(f"TEST SUMMARY: {passed}/{total_commands} assertions passed")
