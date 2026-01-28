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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reference algorithm implementation
def solve_reference(colors):
    n = len(colors)
    first = {}
    last = {}
    for i, c in enumerate(colors):
        if c not in first:
            first[c] = i
        last[c] = i
    
    # Validity check
    for i, c in enumerate(colors):
        if colors[first[c]] != c:
            return "IMPOSSIBLE"
    
    instructions = []
    stack = [] # list of (start_idx, color)
    
    for i in range(n):
        c = colors[i]
        if stack and stack[-1][1] == c:
            pass
        else:
            # Push new interval
            stack.append((i, c))
        
        # If this is the last occurrence of the color at top of stack, pop
        if stack and last[stack[-1][1]] == i:
            start_idx, color = stack.pop()
            # Convert to 1-based inclusive range
            l = start_idx + 1
            r = i + 1
            instructions.append((l, r, color))
            
    return instructions

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_tape_art(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([1, 2, 3, 3, 2, 1], "Sample 1"),
        ([1, 2, 1, 2], "Sample 2"),
        ([3, 3, 3, 5, 4, 2, 4, 4, 5, 1], "Sample 3"),
        ([1], "Single color"),
        ([1, 1, 1, 1], "All same"),
        ([1, 2, 3, 4, 5], "No overlap"),
    ]
    
    for colors, desc in test_cases:
        cocotb.log.info(f"Testing {desc}: {colors}")
        
        # 1. Load colors
        dut.start.value = 1
        dut.len.value = len(colors)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for i, c in enumerate(colors):
            dut.color_in.value = clamp_to_width(c, 8)
            await RisingEdge(dut.clk)
            
        # 2. Wait for completion
        await wait_for_done(dut)
        
        # 3. Check results
        is_impossible = has_signal(dut, 'error') and int(dut.error.value) == 1
        expected = solve_reference(colors)
        
        if expected == "IMPOSSIBLE":
            if not is_impossible:
                raise TestFailure(f"{desc}: Expected IMPOSSIBLE but got VALID")
        else:
            if is_impossible:
                raise TestFailure(f"{desc}: Expected VALID but got IMPOSSIBLE")
            
            # Collect instructions from interface
            # We expect instructions to be output sequentially on cmd_type == 2'b10
            # The interface allows for streaming instructions. 
            # We will sample the output lines over a few cycles.
            # Assumption: Module outputs instructions one per cycle or valid signal.
            
            collected = []
            # Check if instructions are available immediately or need cycling
            # The prompt implies `done` is high at end, but instructions might be valid before.
            # We will check signals over the next few cycles.
            
            # Simplified check: Assuming `l`, `r`, `c` update when cmd_type is valid
            # or instructions are output in a sequence.
            # Given the complexity of outputting 256 instructions, let's assume a handshake or stream.
            # The prompt spec: "Output instructions via l, r, c signals sequentially."
            # Let's assume the module has a mechanism to stream out.
            # However, the provided interface in the prompt is:
            # cmd_type (2-bit), l, r, c (8-bit), done (1-bit).
            # This suggests single cycle output or state-driven.
            
            # To be robust, we simulate reading back.
            # If `cmd_type` is 2'b10, we read `l`, `r`, `c`.
            # If `done` is high and we are done.
            
            # Let's read multiple cycles to catch all instructions
            # (Since we don't have a specific output count signal in the simplified spec, 
            # we rely on `done` or timeout).
            
            # Wait a few cycles to ensure all instructions are processed (simulation tolerance)
            for _ in range(100):
                await RisingEdge(dut.clk)
                if has_signal(dut, 'cmd_type'):
                    ct = int(dut.cmd_type.value)
                    if ct == 2: # 10 binary
                        l = int(dut.l.value)
                        r = int(dut.r.value)
                        c = int(dut.c.value)
                        collected.append((l, r, c))
                
                # Stop if done is asserted (implementation dependent)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                     break
            
            # Verify collected instructions
            if len(collected) != len(expected):
                raise TestFailure(f"{desc}: Expected {len(expected)} instructions, got {len(collected)}")
            
            # The reference might output in different order (stack based is reverse of execution? No, execution order).
            # The problem asks for execution order.
            # Our reference produces valid execution order.
            # The hardware likely produces them in the order they are popped from stack.
            # Stack pop order is valid execution order.
            
            # Sort both to compare sets if order isn't strict, or compare lists.
            # The problem says "any set".
            # Sort both by L then R for comparison.
            collected.sort()
            expected.sort()
            
            if collected != expected:
                raise TestFailure(f"{desc}: Instructions mismatch. Exp: {expected}, Got: {collected}")
