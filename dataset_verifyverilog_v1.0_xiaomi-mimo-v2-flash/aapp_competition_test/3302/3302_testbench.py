import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def popcount(x):
    return bin(x).count('1')

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_color_code(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases
    test_cases = [
        (6, [6]),  # Impossible
        (3, [1]),  # Standard Gray code
    ]
    
    for n, palette_list in test_cases:
        # Calculate palette mask
        palette_mask = 0
        for p in palette_list:
            if 1 <= p <= 16:
                palette_mask |= (1 << p)
        
        # Start sequence
        dut.n.value = n
        dut.palette_valid.value = palette_mask
        dut.palette_count.value = len(palette_list)
        
        cocotb.log.info(f"Testing n={n}, Palette={palette_list}, Mask={bin(palette_mask)}")
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=50000)
        
        if not is_value_defined(dut.done.value):
            raise TestFailure("Done signal undefined")
            
        if int(dut.done.value) != 1:
            raise TestFailure("Done signal did not go high")
        
        if has_signal(dut, 'impossible') and int(dut.impossible.value) == 1:
            if n == 6 and palette_list == [6]:
                cocotb.log.info("Correctly identified impossible case")
                continue
            else:
                raise TestFailure(f"Incorrectly identified impossible for n={n}, palette={palette_list}")
        
        # Verify sequence
        # We need to read the sequence. Since result_data is sequential, we collect it.
        seq = []
        length = 1 << n
        
        # Check if output is sequential
        for i in range(length):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.result_valid.value) or int(dut.result_valid.value) != 1:
                raise TestFailure(f"result_valid not high at cycle {i}")
            
            val = int(dut.result_data.value)
            idx = int(dut.result_index.value)
            
            if idx != i:
                raise TestFailure(f"Index mismatch: expected {i}, got {idx}")
            
            seq.append(val)
        
        # Check constraints
        if len(set(seq)) != length:
            raise TestFailure(f"Duplicate values found in sequence. Length {len(seq)}, Unique {len(set(seq))}")
        
        for i in range(length - 1):
            d = popcount(seq[i] ^ seq[i+1])
            if d not in palette_list:
                raise TestFailure(f"Invalid distance {d} between {bin(seq[i])} and {bin(seq[i+1])}")
        
        cocotb.log.info(f"Verified sequence of length {length} for n={n}")

    cocotb.log.info("All tests passed!")
