import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 14
N_MAX = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_stick_remover(dut):
    """Main test function for stick removal order."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases: (N, sticks, expected_order_0_indexed)
    # sticks: list of (x1, y1, x2, y2)
    test_cases = [
        (4, [(1,3,2,2), (1,1,3,2), (2,4,7,3), (3,3,5,3)], [1,3,0,2]),
        (4, [(0,0,1,1), (1,2,0,3), (2,2,3,3), (4,0,3,1)], [3,2,0,1]),
        (3, [(4,6,5,5), (2,1,15,1), (3,2,8,7)], [1,2,0]),
    ]
    
    for test_idx, (N, sticks, expected_order) in enumerate(test_cases):
        cocotb.log.info(f"Test case {test_idx+1}: N={N}")
        
        # Set N
        if not has_signal(dut, 'N'):
            raise TestFailure("Signal 'N' not found")
        dut.N.value = N
        
        # Assign sticks to input ports
        for i, (x1, y1, x2, y2) in enumerate(sticks):
            for coord, val in [('x1', x1), ('y1', y1), ('x2', x2), ('y2', y2)]:
                port_name = f"{coord}_{i}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    raise TestFailure(f"Signal '{port_name}' not found")
        
        # Zero out unused sticks
        for i in range(len(sticks), N_MAX):
            for coord in ['x1', 'y1', 'x2', 'y2']:
                port_name = f"{coord}_{i}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = 0
        
        # Pulse start
        if not has_signal(dut, 'start'):
            raise TestFailure("Signal 'start' not found")
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect output indices
        output_indices = []
        cycles_waited = 0
        
        # Wait for all outputs
        while len(output_indices) < N and cycles_waited < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles_waited += 1
            
            if not has_signal(dut, 'valid_out') or not has_signal(dut, 'data_out'):
                raise TestFailure("Missing valid_out or data_out signal")
            
            if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
                data = int(dut.data_out.value)
                output_indices.append(data)
                cocotb.log.info(f"  Received index: {data}")
            
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        # Verify count
        if len(output_indices) != N:
            raise TestFailure(f"Expected {N} outputs, got {len(output_indices)}")
        
        # Verify order
        if output_indices != expected_order:
            raise TestFailure(f"Order mismatch: expected {expected_order}, got {output_indices}")
        
        cocotb.log.info(f"  PASS")
        
        # Reset between tests
        if is_sequential:
            await reset_dut(dut)
    
    cocotb.log.info("All tests passed")
