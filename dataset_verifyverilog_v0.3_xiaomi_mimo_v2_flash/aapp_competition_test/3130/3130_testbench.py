import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_holmes_deduction(dut):
    """Test Holmes deduction module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (known_events, implications_matrix, expected_certain, description)
    # Note: implications_matrix[i][j] = 1 means event i+1 -> event j+1
    # Events are 1-indexed, but we use 0-indexed arrays
    test_cases = [
        # Test Case 1: 1->2, 2->3, known=2
        (
            0b00000010,  # known_events: event2 known
            [
                [0, 1, 0, 0, 0, 0, 0, 0],  # 1->2
                [0, 0, 1, 0, 0, 0, 0, 0],  # 2->3
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
            ],
            0b00000111,  # expected: events 1,2,3 certain
            "Test 1: 1->2, 2->3, known=2"
        ),
        # Test Case 2: 1->3, 2->3, known=3
        (
            0b00000100,  # known_events: event3 known
            [
                [0, 0, 1, 0, 0, 0, 0, 0],  # 1->3
                [0, 0, 1, 0, 0, 0, 0, 0],  # 2->3
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
            ],
            0b00000100,  # expected: only event3 certain
            "Test 2: 1->3, 2->3, known=3"
        ),
        # Test Case 3: 1->2, 1->3, 2->4, 3->4, known=4
        (
            0b00001000,  # known_events: event4 known
            [
                [0, 1, 1, 0, 0, 0, 0, 0],  # 1->2, 1->3
                [0, 0, 0, 1, 0, 0, 0, 0],  # 2->4
                [0, 0, 0, 1, 0, 0, 0, 0],  # 3->4
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
            ],
            0b00001111,  # expected: events 1,2,3,4 certain
            "Test 3: 1->2,1->3,2->4,3->4, known=4"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (known_events, implications, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set implications matrix
            for row in range(8):
                for col in range(8):
                    signal_name = f"implications_{row}_{col}"
                    if has_signal(dut, signal_name):
                        getattr(dut, signal_name).value = implications[row][col]
                    else:
                        # Try alternative naming: implications[row][col] might be a 2D array
                        try:
                            dut.implications[row][col].value = implications[row][col]
                        except:
                            # If both fail, assume implications is already set as a vector of vectors
                            pass
            
            # Set known events
            dut.known_events.value = known_events
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.certain_events.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.certain_events.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected:08b}, got {result:08b}")
            
            cocotb.log.info(f"  PASS: certain_events = {result:08b}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
