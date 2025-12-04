import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_password_recovery(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1 (K=1, M=2)
    s_str = [ord('a'), ord('b'), ord('c'), ord('a')] + [0]*12
    t_map = [
        [ord('b'),ord('c'),0,0],      # T_a
        [ord('c'),ord('d'),0,0],      # T_b
        [ord('d'),ord('a'),0,0],      # T_c
        [ord('d'),ord('d'),0,0],      # T_d
        [ord('e'),ord('e'),0,0]      # Remaining default to ee
    ]
    # Fill remaining letters with ee
    full_t_map = [list(t_map[i]) if i < len(t_map) else [ord('e'),ord('e'),0,0] for i in range(26)]

    # Load inputs
    for i in range(16):
        dut.s_chars[i].value = s_str[i]
    for letter in range(26):
        for char_pos in range(4):
            dut.t_data[letter][char_pos].value = full_t_map[letter][char_pos]

    dut.K.value = 1
    dut.M.value = 2
    dut.positions[0].value = 1   # Should map to 'b'
    dut.positions[1].value = 8   # Should map to 'c'

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done (max 6 cycles for K=1)
    while dut.done.value != 1:
        await RisingEdge(dut.clk)

    # Check outputs
    assert dut.results[0].value == ord('b'), "Test1 query0 failed: expected b"
    assert dut.results[1].value == ord('c'), "Test1 query1 failed: expected c"

    # Add more test cases similarly
    dut._log.info("2/2 tests passed")