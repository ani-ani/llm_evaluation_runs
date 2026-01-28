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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pisa_levitation(dut):
    """Test the Pisa levitation solver."""
    
    N = 8  # Fixed size
    DATA_WIDTH = 4
    
    # Start clock if sequential
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, A, B, left, right, t, expected)
    test_cases = [
        (3, 1, 2, [1,0,0], [2,2,1], [1,0,0], "indistinguishable"),
        (2, 0, 1, [1,0], [1,0], [1,0], "0"),
        (3, 1, 2, [1,2,0], [2,0,1], [0,1,1], "1"),
    ]
    
    for i, (n, A, B, left_list, right_list, t_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i}: A={A}, B={B}")
        
        # Write graph data for n nodes
        for j in range(n):
            # left[j]
            if has_signal(dut, 'left'):
                dut.left[j].value = left_list[j]
            elif has_signal(dut, f'left_{j}'):
                getattr(dut, f'left_{j}').value = left_list[j]
            
            # right[j]
            if has_signal(dut, 'right'):
                dut.right[j].value = right_list[j]
            elif has_signal(dut, f'right_{j}'):
                getattr(dut, f'right_{j}').value = right_list[j]
            
            # t[j]
            if has_signal(dut, 't'):
                dut.t[j].value = t_list[j]
            elif has_signal(dut, f't_{j}'):
                getattr(dut, f't_{j}').value = t_list[j]
        
        # Write A and B
        if has_signal(dut, 'A'):
            dut.A.value = A
        if has_signal(dut, 'B'):
            dut.B.value = B
        
        # Start computation
        if has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        # Read result
        if is_value_defined(dut.result.value):
            result_val = int(dut.result.value)
            ind_flag = (result_val >> 8) & 1
            steps = result_val & 0xFF
            
            if expected == "indistinguishable":
                if ind_flag != 1:
                    raise TestFailure(f"Test {i}: expected indistinguishable, got steps={steps}")
            else:
                expected_steps = int(expected)
                if ind_flag != 0 or steps != expected_steps:
                    raise TestFailure(f"Test {i}: expected steps={expected_steps}, got ind_flag={ind_flag}, steps={steps}")
            
            cocotb.log.info(f"Test {i}: PASS")
        else:
            raise TestFailure(f"Test {i}: result is undefined")