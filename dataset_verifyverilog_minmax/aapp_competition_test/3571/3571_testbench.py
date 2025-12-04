import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_elder_scroll(dut):
    # Create 12.5MHz clock
    clock = Clock(dut.clk, 80, units="ns")  # Arbitrary frequency for simulation
    cocotb.start_soon(clock.start())
    # Test case 1 (scaled-down version)
    test_input = { \
        "view_w": 8, "view_h": 5, "first_line": 2,
        "text_lines": [\
            b"Lorem ipsum d",   # Line 0\
            b"olor sit amet",   # Line 1\
            b"consectetur  ",   # Line 2\
            b"adipisicing ",    # Line 3\
            b"elit sed do  ",   # Line 4\
            b"            ",   # Empty lines for padding\
            b"            ",\
            b"            "\
        ]\
    }
    # Expected wrapping (8-char width):
    # Line0: Lorem
    # Line1: ipsum
    # Line2: dolor
    # Line3: sit
    # Line4: amet
    # Line5: consecte
    # Line6: adipisi
    # Line7: elit
    # Viewport [2-6]: line2-dolor to line6-adipisi
    # thumb_pos = ((5-3)*2)/(8-5) = (2*2)/3 = 1 (integer division)
    expected_thumb_pos = 1
    expected_display = [\
        b"dolor   ",   # Line2
        b"sit     ",   # Line3
        b"amet    ",   # Line4
        b"consecte",   # Line5
        b"adipisi "    # Line6\
    ]
    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    # Apply inputs
    dut.start.value = 0
    dut.view_w.value = test_input["view_w"]
    dut.view_h.value = test_input["view_h"]
    dut.first_line.value = test_input["first_line"]
    for i in range(8):
        dut.text_lines[i].value = test_input["text_lines"][i]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for processing (15 cycles)
    await ClockCycles(dut.clk, 16)
    # Verify outputs
    assert dut.done.value == 1, "done not asserted"
    assert dut.thumb_pos.value == expected_thumb_pos, f"Thumb pos {int(dut.thumb_pos.value)} != expected {expected_thumb_pos}"
    for i in range(5):
        observed = bytes([int(dut.display_out[i].value)]).decode('ascii')
        expected = expected_display[i].decode('ascii')
        assert observed.strip() == expected.strip(), f"Line {i}: '{observed}' != '{expected}'"
    # Test summary
    dut._log.info("1/1 tests passed")