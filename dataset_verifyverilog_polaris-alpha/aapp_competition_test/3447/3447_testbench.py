import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_t9(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test Case 1: echoecho using 1-word dict
    dict1 = [b'echo     ', b'        ', b'        ', b'        ', b'        ', b'        ', b'        ', b'        ']
    query1 = b'echoecho'
    # Test Case 2: 'no' using 4-word dict
    dict2 = [b'on      ', b'm       ', b'n       ', b'o       ', b'        ', b'        ', b'        ', b'        ']
    query2 = b'no'
    # Setup and run tests
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    # Test Case 1
    for i in range(8):
        dut.dict[i].value = int.from_bytes(dict1[i], 'big')
    dut.query_word.value = int.from_bytes(query1, 'big')
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(15):
        await RisingEdge(dut.clk)
    assert dut.done.value == 1, "TC1: Result not ready"
    seq = bytes([dut.key_seq[i].value for i in range(dut.seq_len.value)])
    assert seq == b'3246R3246', f"TC1: Got {seq}, expected 3246R3246"
    # Test Case 2
    for i in range(8):
        dut.dict[i].value = int.from_bytes(dict2[i], 'big')
    dut.query_word.value = int.from_bytes(query2, 'big')
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(15):
        await RisingEdge(dut.clk)
    seq = bytes([dut.key_seq[i].value for i in range(dut.seq_len.value)])
    assert seq.startswith(b'6') and b'R' in seq, "TC2: Incorrect sequence"
    dut._log.info("2/2 tests passed")