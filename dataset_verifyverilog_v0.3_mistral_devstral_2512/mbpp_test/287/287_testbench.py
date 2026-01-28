import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_square_sum(dut):
    """Test the square_sum module."""
    
    # Check if sequential or combinational
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    has_start = has_signal(dut, 'start')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    else:
        # Combinational - wait for propagation
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        (2, 20, "n=2"),
        (3, 56, "n=3"),
        (4, 120, "n=4"),
        (0, 0, "n=0"),
        (1, 4, "n=1")
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set input n
            dut.n.value = n_val
            
            if is_sequential:
                # Pulse start
                if has_start:
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    # Wait for done
                    for _ in range(MAX_CYCLES):
                        await RisingEdge(dut.clk)
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            break
                else:
                    await RisingEdge(dut.clk)
            else:
                # Combinational - wait for propagation
                await Timer(50, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")