import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check for defined values
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tribonacci(dut):
    """Test the tribonacci sequence generator."""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (N, expected_sequence)
    test_cases = [
        (0, [1]),
        (1, [1, 3]),
        (2, [1, 3, 2]),
        (3, [1, 3, 2, 8]),
        (4, [1, 3, 2, 8, 3]),
        (5, [1, 3, 2, 8, 3, 15]),
        (6, [1, 3, 2, 8, 3, 15, 4]),
        (7, [1, 3, 2, 8, 3, 15, 4, 24]),
        (8, [1, 3, 2, 8, 3, 15, 4, 24, 5]),
        (9, [1, 3, 2, 8, 3, 15, 4, 24, 5, 35]),
        (10, [1, 3, 2, 8, 3, 15, 4, 24, 5, 35, 6])
    ]
    
    for n_val, expected_seq in test_cases:
        dut._log.info(f"Testing N={n_val}, expecting {expected_seq}")
        
        # Set n_in and pulse start
        dut.n_in.value = n_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect results
        received_seq = []
        cycles_waited = 0
        max_cycles = 50  # Should be enough for N=10
        
        while cycles_waited < max_cycles:
            # Wait for next clock edge
            await RisingEdge(dut.clk)
            await Timer(1, units='ns') # Propagation delay
            
            # Check if value is valid
            if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                val = int(dut.result.value)
                received_seq.append(val)
                dut._log.info(f"  Received value: {val}")
            
            # Check if done
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
                
            cycles_waited += 1
        else:
            raise TestFailure(f"Timeout for N={n_val}. Sequence incomplete.")
            
        # Verify sequence
        if received_seq != expected_seq:
            raise TestFailure(f"N={n_val}: Expected {expected_seq}, got {received_seq}")
            
        dut._log.info(f"N={n_val} passed [OK]")
        
        # Small gap between tests
        await Timer(10, units='ns')
        
    dut._log.info("All tests passed [SUCCESS]")
