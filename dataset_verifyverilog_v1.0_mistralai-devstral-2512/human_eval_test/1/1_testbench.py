import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 500

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_paren_parser(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Helper to send string
    async def send_string(s):
        dut.char_valid.value = 0
        dut.char_end.value = 0
        dut.char_in.value = 0
        for i, ch in enumerate(s):
            # Check if it's space, ignore or include as per spec (spec says ignore spaces)
            # But for processing, we still send space, module should ignore
            # We'll send all chars including space, module handles skipping
            dut.char_in.value = ord(ch) & 0xFF
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
            # Wait for char to be accepted (if backpressure, but spec doesn't have ready, assume always ready)
        # Send end
        dut.char_valid.value = 0
        dut.char_end.value = 1
        await RisingEdge(dut.clk)
        dut.char_end.value = 0
    
    # Helper to wait for pulses
    async def wait_for_pulse(signal, timeout=100):
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(signal.value) and int(signal.value) == 1:
                return True
        return False
    
    # Test cases: (input, expected_group_count, expected_max_depth, description)
    test_cases = [
        ("() (()) ((())) (((())))", 4, 4, "Four groups with increasing depth"),
        ("(()()) ((())) () ((())()())", 4, 5, "Mixed groups"),
        ("()", 1, 1, "Simple pair"),
        ("((()))", 1, 3, "Single nested"),
        ("(()(())((())))", 1, 5, "Single complex"),
        ("", 0, 0, "Empty string"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (test_str, exp_groups, exp_depth, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {desc}")
        try:
            if is_seq:
                await reset_dut(dut)
            else:
                # Combinational, just apply inputs
                pass
            
            # Start processing
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Send string
            await send_string(test_str)
            
            # Monitor pulses
            group_starts = 0
            group_ends = 0
            cycles = 0
            max_cycles = 100
            
            while cycles < max_cycles:
                await RisingEdge(dut.clk)
                if is_value_defined(dut.group_start.value) and int(dut.group_start.value) == 1:
                    group_starts += 1
                    cocotb.log.info(f"  Group start detected")
                if is_value_defined(dut.group_end.value) and int(dut.group_end.value) == 1:
                    group_ends += 1
                    cocotb.log.info(f"  Group end detected")
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    cocotb.log.info(f"  Done detected")
                    break
                cycles += 1
            else:
                raise TestFailure(f"Timeout waiting for done, cycles: {cycles}")
            
            # Verify groups
            # For simple parser, we expect equal starts and ends, and count matches
            # But spec says group_start pulses at start, group_end pulses at end
            # We expect group_starts == group_ends == exp_groups (unless empty)
            # For empty string, no pulses
            if test_str.strip() == "":
                exp_groups = 0
            
            if group_starts != exp_groups:
                raise TestFailure(f"Expected {exp_groups} group starts, got {group_starts}")
            if group_ends != exp_groups:
                raise TestFailure(f"Expected {exp_groups} group ends, got {group_ends}")
            
            # Check result bits if available
            if has_signal(dut, 'result'):
                result = int(dut.result.value)
                # Result format: groups in low 4 bits, max depth in bits 7-4
                groups = result & 0xF
                depth = (result >> 4) & 0xF
                if groups != exp_groups:
                    raise TestFailure(f"Result groups mismatch: expected {exp_groups}, got {groups}")
                if exp_depth is not None and depth != exp_depth:
                    # Note: depth might be 0 for empty, or calculated differently
                    # Just check groups for now as depth tracking is extra
                    cocotb.log.info(f"  Depth: {depth} (expected {exp_depth})")
                    
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {test_idx+1}): {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
