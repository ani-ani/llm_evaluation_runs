import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_decimal_checker(dut):
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (string, expected_valid)
    test_cases = [
        ('123.11   ', True),  # padded
        ('e666.86  ', False),
        ('3.124587 ', False),
        ('1.11     ', True),
        ('1.1.11   ', False),
        ('123      ', True),   # integer only
        ('.12      ', False),  # no integer part
        ('123.     ', False),  # no fractional
        ('123.1    ', True),
        ('999.99   ', True),
    ]
    
    for i, (s, exp_valid) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{s.strip()}' -> {'valid' if exp_valid else 'invalid'}")
        
        # Ensure string is exactly 8 chars
        s_full = (s + ' ' * 8)[:8]
        
        # Feed characters sequentially
        for idx in range(8):
            char = ord(s_full[idx])
            dut.char_in.value = clamp_to_width(char, 8)
            dut.idx.value = clamp_to_width(idx, 3)
            dut.last_char.value = 1 if idx == 7 else 0
            
            if idx == 0:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                await RisingEdge(dut.clk)
            
            # Debug: read state
            if has_signal(dut, 'state_debug') and is_value_defined(dut.state_debug.value):
                state = int(dut.state_debug.value)
                cocotb.log.debug(f"  idx={idx}, state={state}")
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=10)
            
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            result_valid = bool(int(dut.valid.value))
            if result_valid != exp_valid:
                raise TestFailure(f"Expected valid={exp_valid}, got {result_valid}")
            
            # Reset for next test
            await reset_dut(dut, cycles=1)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            raise
    
    cocotb.log.info(f"All {len(test_cases)} tests passed")