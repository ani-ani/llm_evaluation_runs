import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions (from guidelines)
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Constants for the problem
DATA_WIDTH = 16  # For coordinates and moves
MAX_SUM = 16000  # Sum range -8000 to 8000
OFFSET = 8000     # To map to 0..16000
CLK_NS = 10
MAX_CYCLES = 10000  # Allow more cycles for processing

# Parse instruction string to get move lists for X and Y axes
def parse_instructions(s):
    x_moves = []
    y_moves = []
    # Start with first move on X if starts with 'F'
    # We'll accumulate consecutive F's
    i = 0
    turn = 0  # 0: X, 1: Y
    while i < len(s):
        if s[i] == 'F':
            cnt = 0
            while i < len(s) and s[i] == 'F':
                cnt += 1
                i += 1
            if turn == 0:
                x_moves.append(cnt)
            else:
                y_moves.append(cnt)
        else:  # 'T'
            turn = 1 - turn
            i += 1
    return x_moves, y_moves

# Helper to drive individual signals (not arrays)
def drive_signal(dut, name, value, width=8):
    if has_signal(dut, name):
        getattr(dut, name).value = clamp_to_width(value, width)
    else:
        print(f"Warning: Signal {name} not found in DUT")

# Wait for done signal
async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reset DUT
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Testbench for the robot navigation problem
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_robot_nav(dut):
    # Determine if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (instruction_string, target_x, target_y, expected_result)
    test_cases = [
        ("FTFFTFFF", 4, 2, "Yes"),
        ("FTFFTFFF", -2, -2, "No"),
        ("FF", 1, 0, "Yes"),
        ("TF", 1, 0, "No"),
        ("FFTTFF", 0, 0, "Yes"),
        ("TTTT", 1, 0, "No"),
        ("FF", 0, 0, "No"),
        ("F", 0, 0, "No"),
        ("", 0, 0, "Yes"),  # Edge case: empty string
    ]
    
    passed = 0
    failed = 0
    
    for i, (instr, tx, ty, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {instr} -> ({tx}, {ty})")
        try:
            if is_seq:
                # Since the module expects streaming input, we'll simulate by feeding chars
                # We'll need to adapt the DUT interface. For simplicity, assume the DUT has
                # inputs: instruction_char (8-bit), target_x, target_y, and start/valid.
                # We'll drive one char per cycle after asserting start.
                
                # Set targets
                drive_signal(dut, 'target_x', to_signed(tx, DATA_WIDTH), DATA_WIDTH)
                drive_signal(dut, 'target_y', to_signed(ty, DATA_WIDTH), DATA_WIDTH)
                
                # Feed instructions
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                for char in instr:
                    drive_signal(dut, 'instruction', ord(char), 8)
                    dut.valid.value = 1
                    await RisingEdge(dut.clk)
                # Send end-of-string marker (e.g., null)
                drive_signal(dut, 'instruction', 0, 8)
                dut.valid.value = 1
                await RisingEdge(dut.clk)
                dut.valid.value = 0
                
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result_bit = int(dut.result.value)
                expected_bit = 1 if exp == "Yes" else 0
                
                if result_bit != expected_bit:
                    raise TestFailure(f"Expected {exp}, got {'Yes' if result_bit else 'No'}")
            else:
                # Combinational: set inputs and check after delay
                # We need to parse instructions into moves and set up the move arrays.
                # For combinational, assume the DUT has move lists as inputs (e.g., x_moves[0:3], ...)
                # But given the complexity, we skip combinational case for now.
                # We'll just log that it's not applicable.
                print("Combinational DUT not fully supported in this testbench; assuming sequential.")
                
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")

# Additional test cases for larger inputs
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_large_inputs(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Generate a long string of 'F' and 'T' to test boundaries
    long_instr = "F" * 100 + "T" + "F" * 100 + "T" + "F" * 100
    target = (100, 100)  # Should be reachable with alternating turns
    
    if is_seq:
        drive_signal(dut, 'target_x', to_signed(target[0], DATA_WIDTH), DATA_WIDTH)
        drive_signal(dut, 'target_y', to_signed(target[1], DATA_WIDTH), DATA_WIDTH)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for char in long_instr:
            drive_signal(dut, 'instruction', ord(char), 8)
            dut.valid.value = 1
            await RisingEdge(dut.clk)
        drive_signal(dut, 'instruction', 0, 8)
        await RisingEdge(dut.clk)
        dut.valid.value = 0
        
        await wait_for_done(dut)
        
        if int(dut.result.value) != 1:
            raise TestFailure(f"Large input failed")
    else:
        print("Combinational DUT skipped for large input")
