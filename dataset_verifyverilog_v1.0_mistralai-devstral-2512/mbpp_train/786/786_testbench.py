import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(100, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, vals, width=8, size=16):
    """Write values to individual array elements."""
    for i in range(min(len(vals), size)):
        attr = f'arr_{i}'
        if has_signal(dut, attr):
            getattr(dut, attr).value = clamp_to_width(vals[i], width)
        else:
            # Handle 2D array indexing if supported
            try:
                dut.arr[i].value = clamp_to_width(vals[i], width)
            except Exception as e:
                cocotb.log.error(f"Failed to write arr[{i}]: {e}")
    # Pad with 0 if necessary
    for i in range(len(vals), size):
        attr = f'arr_{i}'
        if has_signal(dut, attr):
            getattr(dut, attr).value = 0
        else:
            try:
                dut.arr[i].value = 0
            except Exception:
                pass

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_right_insertion(dut):
    CLK_NS = 10
    
    # Setup clock if present
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')
        # Combinational logic assumption
        dut.rst_n.value = 1
    
    # Test cases
    # 1. Insert at end: [1,2,4,5] val 6 -> index 4
    # 2. Insert middle: [1,2,4,5] val 3 -> index 2
    # 3. Insert end (value > all): [1,2,4,5] val 7 -> index 4
    
    test_cases = [
        (1, [1, 2, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 4, 6, "Insert at end"),
        (2, [1, 2, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 4, 3, "Insert middle"),
        (3, [1, 2, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 4, 7, "Insert at end (larger)"),
    ]
    
    passed = 0
    failed = 0
    
    for case_id, arr_vals, length, val, desc in test_cases:
        cocotb.log.info(f"Running Test {case_id}: {desc}")
        try:
            # Write inputs
            await write_array(dut, arr_vals)
            dut.val.value = clamp_to_width(val, 8)
            dut.len.value = clamp_to_width(length, 4)
            
            if has_signal(dut, 'clk'):
                # Sequential logic
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                await wait_for_done(dut)
                
                if not is_value_defined(dut.index.value):
                    raise TestFailure("Result index undefined")
                
                result = int(dut.index.value)
                # Note: result is 0-16, fit in 4 bits
                expected = 4 if desc == "Insert at end" or desc == "Insert at end (larger)" else 2
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1
            else:
                # Combinational logic
                await Timer(1, units='ns')
                if not is_value_defined(dut.index.value):
                    raise TestFailure("Result index undefined")
                result = int(dut.index.value)
                expected = 4 if desc == "Insert at end" or desc == "Insert at end (larger)" else 2
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1
                    
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {case_id}): {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")