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
# CONFIGURATION
# ============================================================================

MAX_GUESTS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_adj_matrix(dut, adj_matrix, n):
    """Write adjacency matrix to DUT."""
    for i in range(n):
        for j in range(n):
            if has_signal(dut, f'adj_{i}_{j}'):
                getattr(dut, f'adj_{i}_{j}').value = adj_matrix[i][j]
            else:
                # Try indexed array
                try:
                    dut.adj[i][j].value = adj_matrix[i][j]
                except (AttributeError, TypeError):
                    raise TestFailure(f"Cannot write adj[{i}][{j}]")

async def read_sequence(dut, max_len):
    """Read sequence from DUT."""
    sequence = []
    for i in range(max_len):
        if has_signal(dut, f'sequence_{i}'):
            val = getattr(dut, f'sequence_{i}').value
            if is_value_defined(val):
                sequence.append(int(val))
        else:
            try:
                val = dut.sequence[i].value
                if is_value_defined(val):
                    sequence.append(int(val))
            except (AttributeError, TypeError):
                pass
    return sequence

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
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
# TEST IMPLEMENTATION
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_friendship_clique(dut):
    """Test the friendship clique module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, adjacency_matrix, expected_steps, expected_sequence)
    test_cases = [
        # Example 1 from problem
        (
            5,
            [
                [0, 1, 1, 0, 0],  # Guest 1
                [1, 0, 1, 0, 1],  # Guest 2
                [1, 1, 0, 1, 0],  # Guest 3
                [0, 0, 1, 0, 1],  # Guest 4
                [0, 1, 0, 1, 0],  # Guest 5
            ],
            2,
            [2, 3]
        ),
        # Example 2 from problem
        (
            4,
            [
                [0, 1, 1, 1],  # Guest 1
                [1, 0, 0, 0],  # Guest 2
                [1, 0, 0, 1],  # Guest 3
                [1, 0, 1, 0],  # Guest 4
            ],
            1,
            [1]
        ),
        # Simple case: 3 guests in a line
        (
            3,
            [
                [0, 1, 0],  # Guest 1
                [1, 0, 1],  # Guest 2
                [0, 1, 0],  # Guest 3
            ],
            1,
            [2]
        ),
        # Already complete graph
        (
            3,
            [
                [0, 1, 1],
                [1, 0, 1],
                [1, 1, 0],
            ],
            0,
            []
        ),
        # Star graph
        (
            4,
            [
                [0, 1, 1, 1],
                [1, 0, 0, 0],
                [1, 0, 0, 0],
                [1, 0, 0, 0],
            ],
            1,
            [1]
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, adj_matrix, expected_steps, expected_sequence) in enumerate(test_cases):
        if n > MAX_GUESTS:
            cocotb.log.info(f"Test {i+1}: Skipping - n={n} exceeds MAX_GUESTS={MAX_GUESTS}")
            continue
            
        cocotb.log.info(f"Test {i+1}: n={n}, expected steps={expected_steps}")
        
        try:
            # Set inputs
            dut.n.value = n
            
            # Write adjacency matrix
            for row in range(MAX_GUESTS):
                for col in range(MAX_GUESTS):
                    if row < n and col < n:
                        val = adj_matrix[row][col]
                    else:
                        val = 0
                    
                    # Try different access patterns
                    if has_signal(dut, f'adj_{row}_{col}'):
                        getattr(dut, f'adj_{row}_{col}').value = val
                    else:
                        try:
                            dut.adj[row][col].value = val
                        except (AttributeError, TypeError):
                            # Try packed array
                            pass
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            steps = int(dut.steps.value)
            sequence = await read_sequence(dut, MAX_GUESTS)
            
            # Filter out zeros from sequence
            sequence = [x for x in sequence if x != 0]
            
            # Verify steps
            if steps != expected_steps:
                raise TestFailure(f"Steps mismatch: expected {expected_steps}, got {steps}")
            
            # Verify sequence length
            if len(sequence) != len(expected_sequence):
                raise TestFailure(f"Sequence length mismatch: expected {len(expected_sequence)}, got {len(sequence)}")
            
            # Note: We don't verify exact sequence order since multiple valid sequences exist
            cocotb.log.info(f"  PASS: steps={steps}, sequence={sequence}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
