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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# TEST CASES - SCALED DOWN FOR HARDWARE
# ============================================================================

# Original problem scaled to N=8 nodes, P=16 edges, fees scaled to 16-bit

# Sample 1: Expected T=3 (scaled)
TEST_CASE_1 = {
    'N': 6, 'P': 8, 'X': 1, 'Y': 6,
    'edges': [
        (1, 2, 5), (1, 3, 1), (2, 6, 6), (2, 3, 6),
        (4, 2, 3), (3, 4, 1), (4, 5, 1), (5, 6, 1)
    ],
    'swerc': [1, 3, 6, 5, 4],  # 5 banks
    'expected': 3
}

# Sample 2: Expected Infinity
TEST_CASE_2 = {
    'N': 3, 'P': 4, 'X': 1, 'Y': 2,
    'edges': [
        (1, 2, 6), (1, 3, 2), (1, 2, 7), (2, 3, 3)
    ],
    'swerc': [1, 2],
    'expected': 'Infinity'
}

# Sample 3: Expected Impossible
TEST_CASE_3 = {
    'N': 4, 'P': 4, 'X': 1, 'Y': 4,
    'edges': [
        (1, 2, 1), (1, 3, 1), (2, 4, 1), (3, 4, 1)
    ],
    'swerc': [1, 2, 4],
    'expected': 'Impossible'
}

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_swerc_solver(dut):
    """Test the SWERC solver module with scaled problem instances."""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    
    # Setup clock if sequential
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    if has_rst:
        dut.rst_n.value = 0
        if has_start:
            dut.start.value = 0
        if has_clk:
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        if has_clk:
            await RisingEdge(dut.clk)
    
    # Helper function to pack graph data
    def pack_swerc_list(swerc_banks):
        """Pack up to 8 bank IDs into 32-bit word (4 bits each)."""
        packed = 0
        for i, bank in enumerate(swerc_banks[:8]):
            packed |= (bank & 0xF) << (i * 4)
        return packed
    
    def pack_edges(edges):
        """Pack edges into 32-bit words: 4 edges per word."""
        # Each edge: 3-bit a, 3-bit b, 26-bit fee (scaled to fit)
        packed = 0
        for i, (a, b, fee) in enumerate(edges[:4]):
            # Scale fee: original was up to 1e9, we scale to 26-bit (max ~67M)
            scaled_fee = fee // 1000  # Simple scaling
            packed |= ((a & 0x7) << (i*8))
            packed |= ((b & 0x7) << (i*8 + 3))
            packed |= ((scaled_fee & 0x3FFFFFF) << (i*8 + 6))
        return packed
    
    # Test cases
    test_cases = [
        ("Sample 1: Basic", TEST_CASE_1),
        ("Sample 2: Infinity", TEST_CASE_2),
        ("Sample 3: Impossible", TEST_CASE_3),
    ]
    
    for test_name, test_data in test_cases:
        dut._log.info(f"Running {test_name}")
        
        # Pack inputs
        swerc_packed = pack_swerc_list(test_data['swerc'])
        edge_packed = pack_edges(test_data['edges'])
        
        # Apply inputs
        if has_signal(dut, 'N'):
            dut.N.value = test_data['N']
        if has_signal(dut, 'P'):
            dut.P.value = test_data['P']
        if has_signal(dut, 'X'):
            dut.X.value = test_data['X']
        if has_signal(dut, 'Y'):
            dut.Y.value = test_data['Y']
        if has_signal(dut, 'swerc_count'):
            dut.swerc_count.value = len(test_data['swerc'])
        if has_signal(dut, 'swerc_list'):
            dut.swerc_list.value = swerc_packed
        if has_signal(dut, 'edge_data'):
            dut.edge_data.value = edge_packed
        
        # Start computation
        if has_start:
            dut.start.value = 1
            if has_clk:
                await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for done or timeout
        if has_signal(dut, 'done'):
            timeout = 0
            while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
                if has_clk:
                    await RisingEdge(dut.clk)
                timeout += 1
                if timeout > 1000:
                    raise TestFailure(f"Timeout waiting for done in {test_name}")
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined in {test_name}")
        
        result = int(dut.result.value)
        
        # Check result
        expected = test_data['expected']
        if expected == 'Infinity':
            if result != 1:
                raise TestFailure(f"{test_name}: Expected Infinity (1), got {result}")
        elif expected == 'Impossible':
            if result != 0:
                raise TestFailure(f"{test_name}: Expected Impossible (0), got {result}")
        else:
            if result != expected:
                raise TestFailure(f"{test_name}: Expected {expected}, got {result}")
        
        dut._log.info(f"{test_name}: PASS (result={result})")
        
        # Reset for next test
        if has_rst:
            dut.rst_n.value = 0
            if has_clk:
                await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            if has_clk:
                await RisingEdge(dut.clk)
    
    dut._log.info("All tests completed successfully!")
