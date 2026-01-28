import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TEST CONFIGURATION
# ============================================================================
MOD = 100003
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_pokenom_painter(dut):
    """Test the pokenom_painter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (M, N, c_list, expected_X, expected_Ym)
    test_cases = [
        (3, 3, [3,2,1], 0, 672),
        (4, 4, [4,3,1,0], 0, 16296),
        (2, 2, [2,1], 0, 2),
        (2, 2, [1,1], 0, 2),
    ]
    
    for i, (M, N, c_list, exp_X, exp_Ym) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: M={M}, N={N}, c={c_list}")
        
        # Set M and N
        dut.M.value = M
        dut.N.value = N
        
        # Set c_i ports (there are 8 ports)
        for idx in range(8):
            port_name = f'c_{idx}'
            if has_signal(dut, port_name):
                if idx < len(c_list):
                    getattr(dut, port_name).value = c_list[idx]
                else:
                    getattr(dut, port_name).value = 0
            else:
                raise TestFailure(f"Port {port_name} not found")
        
        # Wait a few cycles for inputs to settle
        await Timer(CLK_PERIOD_NS * 2, units='ns')
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done in test {i+1}")
        
        # Read outputs
        X = int(dut.X.value)
        Y_m = int(dut.Y_m.value)
        
        # Verify
        if X != exp_X:
            raise TestFailure(f"Test {i+1}: X mismatch. Expected {exp_X}, got {X}")
        if Y_m != exp_Ym:
            raise TestFailure(f"Test {i+1}: Y_m mismatch. Expected {exp_Ym}, got {Y_m}")
        
        cocotb.log.info(f"  PASS: X={X}, Y_m={Y_m}")
        
        # Reset before next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)