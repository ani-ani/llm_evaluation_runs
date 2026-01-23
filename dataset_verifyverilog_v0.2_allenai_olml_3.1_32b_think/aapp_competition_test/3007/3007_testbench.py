import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def safe_int(signal):
    """Safely convert signal to int, handling X values"""
    try:
        return int(signal.value)
    except ValueError:
        # Signal contains X or Z values
        return None

@cocotb.test()
async def test_max_bling_calculator(dut):
    """Test the Max Bling Calculator with various scenarios"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.d_in.value = 0
    dut.b_in.value = 0
    dut.f_in.value = 0
    dut.t0_in.value = 0
    dut.t1_in.value = 0
    dut.t2_in.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)  # Extra cycle after reset
    
    # Test cases
    test_cases = [
        (4, 0, 1, 0, 0, 0, 300),
        (5, 0, 1, 0, 1, 0, 1900),
        (6, 0, 1, 1, 0, 0, 2300),
        (10, 399, 0, 0, 0, 0, 399),
        (1, 400, 0, 0, 0, 0, 500),
    ]
    
    for i, (d, b, f, t0, t1, t2, expected) in enumerate(test_cases):
        # Load inputs
        dut.d_in.value = d
        dut.b_in.value = b
        dut.f_in.value = f
        dut.t0_in.value = t0
        dut.t1_in.value = t1
        dut.t2_in.value = t2
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        timeout_cycles = 100
        cycle_count = 0
        
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            
            done_val = safe_int(dut.done)
            if done_val == 1:
                break
            if cycle_count > timeout_cycles:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Wait one more cycle for result to stabilize
        await RisingEdge(dut.clk)
        
        # Check result
        actual = safe_int(dut.result)
        
        if actual is None:
            raise TestFailure(f"Test {i+1} failed: Result contains X/Z values. Raw: {dut.result.value}")
        
        if actual != expected:
            raise TestFailure(f"Test {i+1} failed: Input ({d},{b},{f},{t0},{t1},{t2}) Expected {expected}, got {actual}")
        else:
            dut._log.info(f"Test {i+1} passed: {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)  # Extra settling time
    
    dut._log.info(f"All {len(test_cases)} tests passed!")