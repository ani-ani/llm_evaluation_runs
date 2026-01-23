import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_is_monotonic(dut):
    """Test the is_monotonic module with various arrays."""
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')

    async def load_and_check(array, expected):
        # Go to LOADING state
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Load array elements
        # In this simple testbench, we assume the DUT captures data on specific cycles or signals.
        # Given the prompt, we use 'data_in' and 'index'.
        # However, for a sequential FSM, usually we load one per cycle.
        # Let's assume the DUT expects to be fed data sequentially over N cycles after start.
        # But the prompt says 'index' is provided. Let's stick to the prompt's interface.
        # Actually, a cleaner hardware interface for sequential loading is usually:
        # assert start, then feed data_in every clock cycle. Index is internal.
        # Let's adapt: We will treat 'index' as an internal counter or ignore it for simplicity
        # and drive data_in sequentially if the DUT logic supports it.
        # To match the prompt strictly: we drive 'data_in' and 'index' simultaneously.
        
        dut._log.info(f"Loading array: {array}")
        
        # We need to load N elements. The prompt implies index is provided externally.
        # Let's simulate loading by iterating 0 to 7 and setting index/data_in.
        # Assume the DUT latches data when index valid.
        
        for i, val in enumerate(array):
            dut.data_in.value = val
            dut.index.value = i
            # We might need a 'write' signal, but prompt doesn't specify one.
            # Assuming DUT captures data on clock edge during LOADING state.
            # Let's wait a bit then clock it in.
            await RisingEdge(dut.clk)
        
        # Wait for processing
        # Latency is specified as roughly 10 cycles. Let's wait 12 to be safe.
        for _ in range(12):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.done.value != 1:
            raise TestFailure(f"Module did not assert done. Current state: {dut.state.value}")
            
        if dut.result.value != expected:
            raise TestFailure(f"Result mismatch. Expected {expected}, got {dut.result.value}")
        
        # Reset for next test (or ensure we return to IDLE)
        # The module stays in DONE until reset or reset logic.
        dut.rst_n.value = 0
        await Timer(5, units='ns')
        dut.rst_n.value = 1
        await Timer(5, units='ns')

    # Test 1: Monotonic Non-Increasing [6, 5, 4, 4] (padded to 8)
    # [6, 5, 4, 4, 4, 4, 4, 4] -> True
    await load_and_check([6, 5, 4, 4, 4, 4, 4, 4], 1)

    # Test 2: Monotonic Non-Decreasing [1, 2, 2, 3]
    # [1, 2, 2, 3, 3, 3, 3, 3] -> True
    await load_and_check([1, 2, 2, 3, 3, 3, 3, 3], 1)

    # Test 3: Non-Monotonic [1, 3, 2]
    # [1, 3, 2, 2, 2, 2, 2, 2] -> False
    await load_and_check([1, 3, 2, 2, 2, 2, 2, 2], 0)
    
    dut._log.info("All tests passed!")
}