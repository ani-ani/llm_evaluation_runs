import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_bracket_fix(dut):
    # Check required signals
    required_signals = ['clk', 'rst_n', 'start', 'data_in', 'valid_in', 'result', 'done', 'ready']
    missing = [s for s in required_signals if not has_signal(dut, s)]
    if missing:
        raise TestFailure(f"Missing signals: {missing}")
    
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.valid_in.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (sequence, expected_cost)
    test_cases = [
        ("()", 0),           # Already correct
        ("))((", 4),         # 2+2=4
        ("))((())(", 6),     # Example from problem
        ("()()", 0),         # Already correct
        ("((()))", 0),       # Balanced
        ("))))(((()", 10),   # 4+4+1+1=10
        ("", 0),             # Empty
        ("(", 0xFFFF),       # Imbalanced
        ("))", 0xFFFF),      # Imbalanced
    ]
    
    passed = 0
    failed = 0
    
    for seq, expected in test_cases:
        # Wait for ready
        if not has_signal(dut, 'ready'):
            await Timer(100, units='ns')
        else:
            for _ in range(10):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
                    break
            else:
                raise TestFailure("DUT never became ready")
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send sequence
        for ch in seq:
            dut.data_in.value = 1 if ch == ')' else 0
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            await RisingEdge(dut.clk)  # Extra cycle to process
        
        # Wait for done
        max_cycles = len(seq) + 10
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            cocotb.log.error(f"Test '{seq}': Timeout waiting for done")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test '{seq}': Result undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Check result (handle -1 as 0xFFFF)
        if expected == 0xFFFF:
            if result != 0xFFFF and result != -1:
                cocotb.log.error(f"Test '{seq}': Expected -1 (or 0xFFFF), got {result}")
                failed += 1
            else:
                passed += 1
        else:
            if result != expected:
                cocotb.log.error(f"Test '{seq}': Expected {expected}, got {result}")
                failed += 1
            else:
                passed += 1
        
        # Wait for next ready
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_impossible_case(dut):
    # Test case: "((" - should output -1 (0xFFFF)
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Send "(("
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for ch in "(":
        dut.data_in.value = 0  # '('
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        await RisingEdge(dut.clk)
    
    # Wait for done
    for _ in range(10):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Check result is -1
    result = int(dut.result.value)
    if result != 0xFFFF and result != -1:
        raise TestFailure(f"Expected -1 (0xFFFF), got {result}")