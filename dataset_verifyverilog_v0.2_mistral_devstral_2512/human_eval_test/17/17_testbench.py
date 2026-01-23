import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_parse_music(dut):
    """Test the parse_music module with various musical strings."""
    # Create a clock with a period of 10ns
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.music_string.value = 0
    dut.length.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to run a test case
    async def run_test(input_str, expected_durations):
        print(f"Testing: '{input_str}'")
        
        # Convert string to bytes and then to integer for the 128-bit input
        input_bytes = input_str.encode('ascii')
        dut.music_string.value = int.from_bytes(input_bytes, byteorder='big') << (128 - 8*len(input_bytes))
        dut.length.value = len(input_bytes)
        
        # Start parsing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        collected_results = []
        
        # Wait for processing
        # We expect up to len(expected_durations) results
        timeout = 50 # Safety timeout
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.result_valid.value == 1:
                collected_results.append(int(dut.result.value))
            if dut.done.value == 1:
                break
        
        # Assertions
        assert len(collected_results) == len(expected_durations), f"Expected {len(expected_durations)} notes, got {len(collected_results)}"
        for i, (got, exp) in enumerate(zip(collected_results, expected_durations)):
            assert got == exp, f"Note {i}: expected {exp}, got {got}"
        
        print(f"  Passed: {collected_results}")

    # Test Case 1: Empty string
    await run_test('', [])

    # Test Case 2: Only whole notes
    await run_test('o o o o', [4, 4, 4, 4])

    # Test Case 3: Only quarter notes
    await run_test('.| .| .| .|', [1, 1, 1, 1])

    # Test Case 4: Mixed notes
    await run_test('o| o| .| .| o o o o', [2, 2, 1, 1, 4, 4, 4, 4])

    # Test Case 5: Complex mix
    await run_test('o| .| o| .| o o| o o|', [2, 1, 2, 1, 4, 2, 4, 2])

    print("All tests passed!")