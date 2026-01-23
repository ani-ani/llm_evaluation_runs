import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_lure_of_the_labyrinth(dut):
    """Test the Lure of the Labyrinth solver module"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: Inputs and Expected Outputs
    test_cases = [
        {
            "name": "Sample 1",
            "input_str": "_ 90 22 _ 6 _ _ _ _ 81
_ 40 _ _ _ 12 60 _ 90 _",
            "expected_count": 1,
            "expected_many": 0
        },
        {
            "name": "Sample 2",
            "input_str": "85 55 _ 99 51 _ _ _ _ _
_ _ _ _ _ _ _ 85 63 153",
            "expected_count": 1,
            "expected_many": 0
        },
        {
            "name": "Sample 3",
            "input_str": "160 _ _ 136 _ _ _ _ _ 170
_ _ _ _ 120 _ _ 144 _ _",
            "expected_count": 8640,
            "expected_many": 0
        },
        {
            "name": "Sample 4 (Many)",
            "input_str": "36 99 _ 55 _ 99 _ 77 _ _
_ 144 _ _ 27 _ 21 112 _ _",
            "expected_count": 0,
            "expected_many": 1
        }
    ]

    for tc in test_cases:
        dut._log.info(f"Running test: {tc['name']}")
        
        # Parse input string to flat list of values
        # Input format: Line1 (10 entries), Line2 (10 entries)
        lines = tc['input_str'].split('
')
        values = []
        for line in lines:
            parts = line.split()
            for p in parts:
                if p == '_':
                    values.append(0)
                else:
                    values.append(int(p))
        
        # Send start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream inputs
        for val in values:
            dut.data_in.value = val
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            # Wait for handshake if needed, or just pulse valid
            # Assuming module accepts stream, let's wait a cycle
        
        dut.valid_in.value = 0
        
        # Wait for done
        timeout = 100000  # Safety timeout
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout waiting for done in {tc['name']}")

        # Check results
        count = int(dut.solution_count.value)
        many = int(dut.many.value)
        
        dut._log.info(f"Result: Count={count}, Many={many}")
        
        if many != tc['expected_many']:
             raise TestFailure(f"{tc['name']}: Expected many={tc['expected_many']}, got {many}")
        
        if tc['expected_many'] == 0:
            if count != tc['expected_count']:
                raise TestFailure(f"{tc['name']}: Expected count={tc['expected_count']}, got {count}")
        
        dut._log.info(f"{tc['name']} passed")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info("All tests passed!")
