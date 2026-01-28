import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TEST CASES
# ============================================================================

test_cases = [
    {
        "name": "impossible_case",
        "n": 4,
        "c": 6,
        "edges": [
            (1,2,1987), (2,3,1987), (1,3,1987),
            (2,4,1987), (1,4,1987), (3,4,1987)
        ],
        "expected": 0
    },
    {
        "name": "possible_case",
        "n": 4,
        "c": 2,
        "edges": [
            (1,2,1970),
            (3,4,1980)
        ],
        "expected": 1971
    }
]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_partition_finder(dut):
    """Main test function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Check required signals
    required_signals = ['start', 'n', 'c', 'edge_valid', 'edge_a', 'edge_b', 'edge_y', 'edge_ready', 'result_valid', 'year']
    for sig in required_signals:
        if not has_signal(dut, sig):
            dut._log.error(f"Missing signal: {sig}")
            raise TestFailure(f"Missing signal: {sig}")
    
    for tc in test_cases:
        dut._log.info(f"Running test case: {tc['name']}")
        
        # Set n and c
        dut.n.value = tc['n']
        dut.c.value = tc['c']
        
        # Deassert control signals
        dut.start.value = 0
        dut.edge_valid.value = 0
        
        # Wait a cycle
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed edges
        for a, b, y in tc['edges']:
            a0 = a - 1
            b0 = b - 1
            y_offset = y - 1948
            
            dut.edge_a.value = a0
            dut.edge_b.value = b0
            dut.edge_y.value = y_offset
            dut.edge_valid.value = 1
            
            # Wait for edge_ready high
            for _ in range(100):
                if is_value_defined(dut.edge_ready.value) and int(dut.edge_ready.value) == 1:
                    break
                await RisingEdge(dut.clk)
            else:
                raise TestFailure("Timeout waiting for edge_ready")
            
            await RisingEdge(dut.clk)
            dut.edge_valid.value = 0
        
        # Wait for result_valid
        for _ in range(10000):
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure("Timeout waiting for result_valid")
        
        # Read year
        if not is_value_defined(dut.year.value):
            raise TestFailure("Result year is undefined")
        
        year_val = int(dut.year.value)
        expected = tc['expected']
        
        if year_val != expected:
            raise TestFailure(f"Test {tc['name']}: expected {expected}, got {year_val}")
        
        dut._log.info(f"Test {tc['name']} passed: year = {year_val}")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
