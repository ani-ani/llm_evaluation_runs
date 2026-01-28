import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_time_table(dut, N, M, time_table):
    """Write N*M values to time_table array"""
    for i in range(N):
        for j in range(M):
            idx = i * M + j
            if hasattr(dut, f'time_table_{idx}'):
                getattr(dut, f'time_table_{idx}').value = clamp_to_width(time_table[i][j], 8)
            elif hasattr(dut, 'time_table'):
                dut.time_table[idx].value = clamp_to_width(time_table[i][j], 8)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dog_feeding(dut):
    # Check for clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        Clock(dut.clk, 10, units='ns').start()
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'N': 2, 'M': 3,
            'time_table': [[2, 100, 10], [100, 1, 10]],
            'expected': 0,
            'desc': 'Example 1: Perfect alignment'
        },
        {
            'N': 3, 'M': 3,
            'time_table': [[100, 20, 30], [10, 90, 80], [99, 90, 98]],
            'expected': 12,
            'desc': 'Example 2: Mixed times'
        },
        {
            'N': 2, 'M': 2,
            'time_table': [[5, 10], [10, 5]],
            'expected': 0,
            'desc': 'Simple equal case'
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Test: {tc['desc']}")
        
        try:
            # Set inputs
            N = tc['N']
            M = tc['M']
            
            if has_signal(dut, 'N'):
                dut.N.value = clamp_to_width(N, 6)
            if has_signal(dut, 'M'):
                dut.M.value = clamp_to_width(M, 6)
            
            # Write time table
            await write_time_table(dut, N, M, tc['time_table'])
            
            # Start calculation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            expected = tc['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")
