import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fibfib_basic(dut):
    """Test basic FibFib sequence values."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 0),
        (2, 1),
        (5, 4),
        (8, 24),
        (10, 81),
        (12, 274),
        (14, 927)
    ]
    
    for n, expected in test_cases:
        dut._log.info(f"Testing n={n}, expecting {expected}")
        
        # Set input
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        max_cycles = 20
        done_received = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
                
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Timeout: done not received for n={n} after {max_cycles} cycles")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z) for n={n}")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"n={n}: expected {expected}, got {result}")
            
        dut._log.info(f"n={n}: got {result} [OK]")
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fibfib_base_cases(dut):
    """Test base cases: 0, 1, 2."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test base cases
    base_cases = [(0, 0), (1, 0), (2, 1)]
    
    for n, expected in base_cases:
        dut._log.info(f"Testing base case n={n}, expecting {expected}")
        
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for cycle in range(20):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for base case n={n}")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for n={n}")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Base case n={n}: expected {expected}, got {result}")
            
        dut._log.info(f"Base case n={n}: {result} [OK]")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fibfib_edge_values(dut):
    """Test edge values and sequence progression."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test n=3 and n=4 to verify sequence building
    edge_cases = [
        (3, 1),  # 0+0+1 = 1
        (4, 2),  # 0+1+1 = 2
        (7, 13), # Manual calculation
        (9, 44)  # Manual calculation
    ]
    
    for n, expected in edge_cases:
        dut._log.info(f"Testing edge case n={n}, expecting {expected}")
        
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for cycle in range(25):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for edge case n={n}")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for n={n}")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Edge case n={n}: expected {expected}, got {result}")
            
        dut._log.info(f"Edge case n={n}: {result} [OK]")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fibfib_max_n(dut):
    """Test maximum supported n=15."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Expected value for n=15: 3136
    n = 15
    expected = 3136
    
    dut._log.info(f"Testing maximum n={n}, expecting {expected}")
    
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 20 cycles should be enough)
    for cycle in range(20):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout for max n={n}")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure(f"Result undefined for n={n}")
        
    result = int(dut.result.value)
    if result != expected:
        raise TestFailure(f"Max n={n}: expected {expected}, got {result}")
        
    dut._log.info(f"Max n={n}: {result} [OK]")
