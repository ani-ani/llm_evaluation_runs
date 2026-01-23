import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_min_people_finder(dut):
    # Create a clock with a 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.events.value = 0
    dut.length.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to convert string to packed bit vector (MSB first)
    def encode_events(event_str):
        val = 0
        for char in event_str:
            val <<= 1
            if char == '+':
                val |= 1
            else:
                val |= 0
        return val

    # Test cases adapted from the problem
    # (Input String, Expected Output)
    test_cases = [
        ("+-+-+", 1),
        ("---", 3),
        ("-", 1),
        ("--", 2),
        ("---", 3),
        ("----", 4),
        ("---+", 3),
        ("--+-", 2),
        ("--++", 2),
        ("-+--", 2),
        ("-++", 2),
        ("-++-", 2),
        ("+", 1),
        ("+-", 1),
        ("+--", 2),
        ("+--+", 2),
        ("++--", 2),
        ("-+++--+-++--+-+--+-+", 3)
    ]

    passed = 0
    total = len(test_cases)

    for events_str, expected in test_cases:
        # Prepare inputs
        dut.events.value = encode_events(events_str)
        dut.length.value = len(events_str)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        # Estimated latency: length + 3 cycles (PROCESSING + CALCULATE + DONE)
        timeout = len(events_str) + 10
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test '{events_str}' timed out waiting for done signal")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Test '{events_str}' failed. Expected {expected}, got {actual}")
        
        passed += 1
        # Small delay between tests
        await Timer(5, units='ns')
        
        # Reset for next test (optional but safer if state is not fully cleared by start)
        # Here we rely on the state machine returning to IDLE and being ready for next start

    print(f"
*** Summary: {passed}/{total} tests passed ***")
    assert passed == total, "Some tests failed"
