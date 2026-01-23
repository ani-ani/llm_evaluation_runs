import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def get_unique_count(s):
    # Calculate unique chars ignoring 0
    chars = set([c for c in s if c != 0])
    return len(chars)

def pack_string(s):
    # Pack 8 bytes into a single integer for lexicographical comparison
    # String is list of 8 integers (0-26)
    val = 0
    for i in range(8):
        val |= (s[i] << (i * 8))
    return val

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_find_max(dut):
    """Test the find_max module with various string inputs."""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    # Initialize strings to 0
    for i in range(4):
        for j in range(8):
            dut.strings[i][j].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases
    # Format: (input_strings, expected_string)
    # Characters are mapped 'a'=1, 'b'=2, ..., 'z'=26
    test_cases = [
        # ["name", "of", "string"] -> "string"
        # name: n(14)a(1)m(13)e(5) -> unique=4
        # of: o(15)f(6) -> unique=2
        # string: s(19)t(20)r(18)i(9)n(14)g(7) -> unique=6
        ([14,1,13,5,0,0,0,0], [15,6,0,0,0,0,0,0], [19,20,18,9,14,7,0,0], [0,0,0,0,0,0,0,0], [19,20,18,9,14,7,0,0]),
        
        # ["name", "enam", "game"] -> "enam"
        # name: 14,1,13,5 -> unique=4
        # enam: 5,14,1,13 -> unique=4
        # game: 7,1,13,5 -> unique=4
        # All have 4 unique. Must return first lexicographically.
        # Compare packed integers:
        # name: 14 | (1<<8) | (13<<16) | (5<<24) = 0x050D010E
        # enam: 5 | (14<<8) | (1<<16) | (13<<24) = 0x0D010E05
        # game: 7 | (1<<8) | (13<<16) | (5<<24) = 0x050D0107
        # enam is smallest? 0x0D010E05 > 0x050D010E (Wait, 'enam' < 'name'? No, 'e' < 'n', so 'enam' comes first)
        # Wait, 'enam' (5) < 'game' (7) < 'name' (14). So 'enam' wins.
        ([14,1,13,5,0,0,0,0], [5,14,1,13,0,0,0,0], [7,1,13,5,0,0,0,0], [0,0,0,0,0,0,0,0], [5,14,1,13,0,0,0,0]),
        
        # ["aaaaaaa", "bb", "cc"] -> "aaaaaaa"
        # aaaaaaa: 1,1,1,1,1,1,1 -> unique=1
        # bb: 2,2 -> unique=1
        # cc: 3,3 -> unique=1
        # First string wins.
        ([1]*8, [2,2,0,0,0,0,0,0], [3,3,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [1]*8),
        
        # ["abc", "cba"] -> "abc"
        # abc: 1,2,3 -> unique=3
        # cba: 3,2,1 -> unique=3
        # abc < cba
        ([1,2,3,0,0,0,0,0], [3,2,1,0,0,0,0,0], [0]*8, [0]*8, [1,2,3,0,0,0,0,0]),
        
        # ["play", "this", "game", "of", "footbott"] -> "footbott"
        # We only have 4 inputs, so let's test with 4: ["play", "this", "game", "foot"]
        # play: p(16),l(12),a(1),y(25) -> 4 unique
        # this: t(20),h(8),i(9),s(19) -> 4 unique
        # game: g(7),a(1),m(13),e(5) -> 4 unique
        # foot: f(6),o(15),t(20) -> 3 unique
        # Top 3 have 4 unique. First lexicographically:
        # game (g=7) < play (p=16) < this (t=20). So "game" wins.
        ([16,12,1,25,0,0,0,0], [20,8,9,19,0,0,0,0], [7,1,13,5,0,0,0,0], [6,15,15,20,0,0,0,0], [7,1,13,5,0,0,0,0]),
    ]

    for i, (s0, s1, s2, s3, expected) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}")
        
        # Load inputs
        for j in range(8):
            dut.strings[0][j].value = s0[j]
            dut.strings[1][j].value = s1[j]
            dut.strings[2][j].value = s2[j]
            dut.strings[3][j].value = s3[j]
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 100
        done_seen = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test {i+1}: Done signal not asserted within timeout")
            
        # Verify result
        actual = []
        for j in range(8):
            if not is_value_defined(dut.result[j].value):
                raise TestFailure(f"Test {i+1}: Result[{j}] is undefined")
            actual.append(int(dut.result[j].value))
        
        if actual != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {actual}")
            
    dut._log.info("All tests passed")