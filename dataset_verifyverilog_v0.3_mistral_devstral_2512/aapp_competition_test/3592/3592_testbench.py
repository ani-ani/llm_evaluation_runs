import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH CONFIGURATION
# ============================================================================

PROFIT_WIDTH = 32
PROFIT_PER_WIDTH = 16
COUNT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    # Wait for clock edges
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Start the computation."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def read_solutions(dut):
    """Read all solutions from the DUT."""
    solutions = []
    
    # Monitor valid signals while done is not asserted
    cycles = 0
    while cycles < MAX_CYCLES and not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
        await RisingEdge(dut.clk)
        cycles += 1
        
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            if is_value_defined(dut.pitas.value) and is_value_defined(dut.pizzas.value):
                pitas = int(dut.pitas.value)
                pizzas = int(dut.pizzas.value)
                solutions.append((pitas, pizzas))
    
    return solutions

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_profit_calculator(dut):
    """Main test for profit calculator."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (profit, pita_profit, pizza_profit, expected_solutions, description)
    # Convert floats to cents for integer arithmetic
    test_cases = [
        # Example 1: 725.85, 1.71, 2.38 -> (199, 162)
        (72585, 171, 238, [(199, 162)], "725.85 1.71 2.38"),
        
        # Example 2: 100.00, 20.00, 10.00 -> multiple solutions
        (10000, 2000, 1000, [(0, 10), (1, 8), (2, 6), (3, 4), (4, 2), (5, 0)], "100.00 20.00 10.00"),
        
        # Example 3: No solution (e.g., 1.00, 2.00, 3.00 cannot be solved with integers)
        (100, 200, 300, [], "1.00 2.00 3.00 (no solution)"),
        
        # Example 4: Edge case - 0 profit
        (0, 100, 100, [(0, 0)], "0.00 1.00 1.00"),
        
        # Example 5: Single pita
        (171, 171, 238, [(1, 0)], "1.71 1.71 2.38"),
        
        # Example 6: Single pizza  
        (238, 171, 238, [(0, 1)], "2.38 1.71 2.38"),
    ]
    
    total_passed = 0
    total_failed = 0
    
    for profit_cents, pita_cents, pizza_cents, expected, description in test_cases:
        dut._log.info(f"\nTesting: {description}")
        dut._log.info(f"  Profit: {profit_cents} cents, Pita: {pita_cents} cents, Pizza: {pizza_cents} cents")
        dut._log.info(f"  Expected solutions: {len(expected)}")
        
        try:
            # Set inputs
            dut.profit_cents.value = profit_cents
            dut.pita_profit_cents.value = pita_cents
            dut.pizza_profit_cents.value = pizza_cents
            
            # Start computation
            await start_computation(dut)
            
            # Read solutions
            solutions = await read_solutions(dut)
            
            # Wait for done to ensure completion
            if has_signal(dut, 'done'):
                await wait_for_done(dut)
            else:
                await Timer(500, units='ns')
            
            # Verify results
            if len(solutions) != len(expected):
                raise TestFailure(f"Expected {len(expected)} solutions, got {len(solutions)}")
            
            # Check each solution
            for i, (actual, exp) in enumerate(zip(solutions, expected)):
                if actual != exp:
                    raise TestFailure(f"Solution {i}: expected {exp}, got {actual}")
            
            dut._log.info(f"  PASS: Found {len(solutions)} solutions as expected")
            total_passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            total_failed += 1
    
    # Summary
    dut._log.info("\n" + "="*60)
    dut._log.info(f"FINAL RESULTS: {total_passed}/{total_passed+total_failed} test cases passed")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test(s) failed")
