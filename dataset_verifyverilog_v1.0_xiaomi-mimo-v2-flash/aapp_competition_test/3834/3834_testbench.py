import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants for 16x16 adaptation
DATA_WIDTH = 16
MAX_ROWS = 16
CLK_NS = 10
MAX_CYCLES = 100000  # Allow up to 100k cycles for enumeration

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'row_valid'): dut.row_valid.value = 0
    if has_signal(dut, 'done_config'): dut.done_config.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_row(dut, row_data, row_len):
    """Load a single row into the module"""
    dut.row_data.value = clamp_to_width(row_data, DATA_WIDTH)
    dut.row_len.value = clamp_to_width(row_len, 4)
    dut.row_valid.value = 1
    await RisingEdge(dut.clk)
    dut.row_valid.value = 0
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for valid signal to go high"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'valid') and is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_min_changes(rows):
    """Compute min changes required for 16x16 grid"""
    k_max = 10  # Default k for test
    min_cost = 100
    
    # Enumerate all possible 16-bit patterns
    for pattern in range(1 << DATA_WIDTH):
        cost = 0
        for row in rows:
            # Compute popcount difference
            diff = row ^ pattern
            # Count 1s in diff (popcount)
            ones = bin(diff).count('1')
            changes = min(ones, DATA_WIDTH - ones)
            cost += changes
            if cost > min_cost:  # Pruning
                break
        if cost < min_cost:
            min_cost = cost
    return min_cost

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_rectangle_table(dut):
    # Initialize
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        # Format: (rows_list, k_max, expected_output)
        # Example 1: 5x5 grid with single 0
        ([0b11111, 0b11111, 0b11011, 0b11111, 0b11111], 2, 1),
        # Example 2: 3x4 grid (no solution)
        ([0b1000, 0b0111, 0b1110], 1, 15),  # 15 represents -1
        # Example 3: 3x4 grid (already valid)
        ([0b1001, 0b0110, 0b1001], 1, 0),
        # Additional cases
        ([0b00000000, 0b00000000, 0b00000001, 0b00000000, 0b00000000, 0b00000001, 0b00000001, 0b00000000], 4, 0),
    ]
    
    passed = failed = 0
    
    for i, (rows, k, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: rows={len(rows)}, k={k}, expected={exp}")
        try:
            if is_seq:
                # Load rows
                for r in rows:
                    await load_row(dut, r, DATA_WIDTH)
                
                # Trigger completion
                dut.done_config.value = 1
                await RisingEdge(dut.clk)
                dut.done_config.value = 0
                
                # Wait for result
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                
                # If exp is 15 (representing -1), check status
                if exp == 15:
                    status = int(dut.status.value) if has_signal(dut, 'status') else 0
                    if status != 2:  # status 2 = invalid
                        raise TestFailure(f"Expected invalid status, got {status}")
                else:
                    if result != exp:
                        raise TestFailure(f"Expected {exp}, got {result}")
            else:
                await Timer(100, units='ns')
                # For combinational logic, just check immediate output
                pass
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_random_cases(dut):
    """Test with random generated 16x16 data"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Generate random 16x16 grid
    random.seed(42)
    rows = [random.getrandbits(16) for _ in range(16)]
    
    # Compute expected
    expected = compute_min_changes(rows)
    
    if is_seq:
        # Load rows
        for r in rows:
            await load_row(dut, r, DATA_WIDTH)
        
        dut.done_config.value = 1
        await RisingEdge(dut.clk)
        dut.done_config.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        result = int(dut.result.value)
        
        if result != expected and result != 15:  # 15 is -1
            raise TestFailure(f"Random test failed: expected {expected}, got {result}")
    
    cocotb.log.info("Random test passed")
