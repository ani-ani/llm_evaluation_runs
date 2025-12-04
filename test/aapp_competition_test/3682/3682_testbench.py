import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_code_match(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Match 2 lines
    repo_lines = [
        ("HelloWorld.c    ", True),   # Filename
        ("int Main() {    ", False),
        ("printf("Hello %d\
",i);", False),
        ("}              ", False),
        ("***END***      ", False),
        ("Add.c          ", True),   # Filename
        ("int Main() {   ", False),
        ("for (int i=0;  ", False),
        ("}              ", False),
        ("***END***      ", False)
    ]

    input_code = [
        ("int Main() {     ", False),
        ("printf("Hello %d\
",i);", False),
        ("printf("THE END\
");", False),
        ("}               ", False),
        ("***END***       ", False)
    ]

    # Load repository
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for line, is_filename in repo_lines:
        dut.line_in.value = int.from_bytes(line.encode(), 'big') \u0026 ((1 << 128)-1)
        dut.line_valid.value = 1
        dut.fragment_end.value = 1 if line.strip() == '***END***' else 0
        await RisingEdge(dut.clk)

    # Process input code
    for line, _ in input_code:
        dut.line_in.value = int.from_bytes(line.encode(), 'big') \u0026 ((1 << 128)-1)
        dut.line_valid.value = 1
        dut.fragment_end.value = 1 if line.strip() == '***END***' else 0
        await RisingEdge(dut.clk)

    # Wait for processing
    await ClockCycles(dut.clk, 10)
    assert dut.done.value == 1, "Module did not finish processing"
    assert dut.max_count.value == 2, f"Expected max_count=2, got {dut.max_count.value}"
    fnames = dut.filenames.value
    name1 = fnames \u0026 ((1 << 128)-1)
    name2 = (fnames >> 128) \u0026 ((1 << 128)-1)
    assert name1 == int.from_bytes(b'HelloWorld.c    '[:16].ljust(16), 'big'), "Filename1 mismatch"
    assert name2 == int.from_bytes(b'Add.c          '[:16].ljust(16), 'big'), "Filename2 mismatch"

    dut._log.info("1/1 tests passed")