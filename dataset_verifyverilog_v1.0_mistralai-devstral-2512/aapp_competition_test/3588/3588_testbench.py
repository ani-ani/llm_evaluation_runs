import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration based on scaled spec
MAX_RECORDS = 10
MAX_DAYS = 16
MAX_DAY_VAL = 128
MAX_SHARES = 512

# Helpers
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

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_investor_tax(dut):
    # Check for mandatory signals
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n') and has_signal(dut, 'start')):
        raise TestFailure("Missing mandatory signals: clk, rst_n, start")
    
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'data_valid'): dut.data_valid.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: From Example
    # Input format: (shares, day) pairs
    # 3 companies
    # Company 1: 2 records: (20, 100), (100, 10)
    # Company 2: 1 record: (150, 50)
    # Company 3: 1 record: (150, 100)
    # Expected Output days: 10 (100), 50 (150), 100 (20+150=170)
    # Scaled logic: assuming days are just indices 0-15, or mapped.
    # Let's use the exact values but scaled to fit 9-bit inputs if needed.
    # 100 -> 100, 10 -> 10, 50 -> 50. Max < 128.
    
    records = [
        (20, 100), (100, 10),
        (150, 50),
        (150, 100)
    ]
    
    dut.log.info("Starting Test Case 1: Normal operation")
    
    # Start input phase
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed records: 2 cycles per record (shares then day)
    # We assume the interface accepts shares on data_valid=1, load_cmd=0, then day load_cmd=1
    # Check if 'load_cmd' exists, if not, maybe it's implicit sequence
    
    use_load_cmd = has_signal(dut, 'load_cmd')
    use_data_in = has_signal(dut, 'data_in')
    
    if use_data_in:
        for shares, day in records:
            # Send Shares
            dut.data_in.value = clamp_to_width(shares, 9)
            if use_load_cmd: dut.load_cmd.value = 0
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
            
            # Send Day
            dut.data_in.value = clamp_to_width(day, 9)
            if use_load_cmd: dut.load_cmd.value = 1
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
            
        dut.data_valid.value = 0
    else:
        # Fallback for different interface (e.g., parallel ports)
        # Assuming ports 'shares' and 'day' exist for simplicity if data_in isn't found
        dut.log.warning("data_in not found, checking for parallel ports")
    
    # Wait for computation (Sort + Output)
    # Expected output order by day: 10 (100), 50 (150), 100 (170)
    expected_results = [
        (10, 100),
        (50, 150),
        (100, 170)
    ]
    
    outputs = []
    
    if has_signal(dut, 'output_valid'):
        # Monitor outputs
        for _ in range(100): # Max cycles to wait
            await RisingEdge(dut.clk)
            if is_value_defined(dut.output_valid.value) and int(dut.output_valid.value) == 1:
                day = int(dut.day_out.value) if has_signal(dut, 'day_out') else 0
                res = int(dut.result.value) if has_signal(dut, 'result') else 0
                outputs.append((day, res))
                dut.log.info(f"Output: Day {day}, Shares {res}")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
    else:
        # If no output_valid, wait fixed time and check final state (e.g., memory dump)
        await Timer(1000, units='ns')
        dut.log.warning("No output_valid signal found, checking internal state if accessible")
    
    # Verify Results
    if len(outputs) != len(expected_results):
        raise TestFailure(f"Expected {len(expected_results)} outputs, got {len(outputs)}")
    
    for i, (exp_day, exp_shares) in enumerate(expected_results):
        if i >= len(outputs):
             raise TestFailure(f"Missing output for index {i}")
        
        out_day, out_shares = outputs[i]
        if out_day != exp_day or out_shares != exp_shares:
            raise TestFailure(f"Output {i} mismatch: Expected (Day {exp_day}, {exp_shares}), Got (Day {out_day}, {out_shares})")
    
    dut.log.info("Test Case 1 PASSED")
    
    # --- Test Case 2 ---
    # Reset for second test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    records2 = [
        (200, 63), (100, 25),
        (50, 120), (100, 63),
        (50, 25), (100, 120)
    ]
    # Group by day:
    # Day 25: 100 + 50 = 150
    # Day 63: 200 + 100 = 300
    # Day 120: 50 + 100 = 150
    # Sorted days: 25, 63, 120
    
    expected_results2 = [
        (25, 150),
        (63, 300),
        (120, 150)
    ]
    
    dut.log.info("Starting Test Case 2")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    if use_data_in:
        for shares, day in records2:
            dut.data_in.value = clamp_to_width(shares, 9)
            if use_load_cmd: dut.load_cmd.value = 0
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
            
            dut.data_in.value = clamp_to_width(day, 9)
            if use_load_cmd: dut.load_cmd.value = 1
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
        dut.data_valid.value = 0
    
    outputs2 = []
    if has_signal(dut, 'output_valid'):
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.output_valid.value) and int(dut.output_valid.value) == 1:
                day = int(dut.day_out.value) if has_signal(dut, 'day_out') else 0
                res = int(dut.result.value) if has_signal(dut, 'result') else 0
                outputs2.append((day, res))
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
    
    if len(outputs2) != len(expected_results2):
        raise TestFailure(f"Test 2: Expected {len(expected_results2)} outputs, got {len(outputs2)}")
        
    for i, (exp_day, exp_shares) in enumerate(expected_results2):
        if i >= len(outputs2):
             raise TestFailure(f"Test 2: Missing output for index {i}")
        out_day, out_shares = outputs2[i]
        if out_day != exp_day or out_shares != exp_shares:
            raise TestFailure(f"Test 2: Output {i} mismatch: Expected (Day {exp_day}, {exp_shares}), Got (Day {out_day}, {out_shares})")
            
    dut.log.info("Test Case 2 PASSED")