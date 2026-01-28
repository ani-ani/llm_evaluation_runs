import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_PLAYERS = 100
MAX_ROUNDS = 600
CLK_NS = 10

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

def player_id(team_idx, player_idx):
    return team_idx * 25 + player_idx

def decode_game(packed_byte):
    val = int(packed_byte)
    if val == 0: return None
    team = val // 25
    player = val % 25
    return f"{chr(ord('A')+team)}{player+1}"

def decode_round(result_val, n, m):
    games = []
    result_int = int(result_val)
    for i in range(8):
        p1_byte = (result_int >> (i*16)) & 0xFF
        p2_byte = (result_int >> (i*16 + 8)) & 0xFF
        if p1_byte == 0: break
        p1_str = decode_game(p1_byte)
        p2_str = decode_game(p2_byte)
        if p1_str and p2_str:
            games.append(f"{p1_str}-{p2_str}")
    return games

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_schedule(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await Timer(100, units='ns')
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(10, units='ns')
    
    # Test cases
    test_cases = [
        (3, 2, 3, ["A1-B2 B1-A2 A3-B3", "A2-B3 B2-A3 A1-B1", "A3-B1 B3-A1 A2-B2"]),
        (2, 3, 4, ["A1-B1 A2-C2 B2-C1", "A1-C1 A2-B1 B2-C2", "A1-B2 A2-C1 B1-C2", "A1-C2 A2-B2 B1-C1"]),
        (1, 5, 5, ["B1-E1 C1-D1", "C1-A1 D1-E1", "D1-B1 E1-A1", "E1-C1 A1-B1", "A1-D1 B1-C1"]),
    ]
    
    for (n, m, expected_rounds, expected_lines) in test_cases:
        dut.n.value = n
        dut.m.value = m
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await Timer(10, units='ns')
        
        rounds_found = []
        
        # Collect rounds
        for _ in range(MAX_ROUNDS):
            # Wait for result to be valid
            await Timer(20, units='ns')
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            
            # Check if done
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    break
            
            # Read result
            if has_signal(dut, 'result') and is_value_defined(dut.result.value):
                result_val = int(dut.result.value)
                if result_val != 0:  # Valid round
                    games = decode_round(result_val, n, m)
                    if games:
                        line = " ".join(games)
                        rounds_found.append(line)
        
        # Verify
        if len(rounds_found) != expected_rounds:
            raise TestFailure(f"n={n}, m={m}: Expected {expected_rounds} rounds, got {len(rounds_found)}")
        
        # Verify content (allow any order)
        found_expected = [False] * expected_rounds
        for line in rounds_found:
            for i, exp_line in enumerate(expected_lines):
                # Compare sorted content
                if sorted(line.split()) == sorted(exp_line.split()):
                    found_expected[i] = True
                    break
        
        if not all(found_expected):
            raise TestFailure(f"n={n}, m={m}: Missing expected lines")
        
        cocotb.log.info(f"Test passed for n={n}, m={m}")
        
        # Reset for next test
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await Timer(50, units='ns')
            dut.rst_n.value = 1
            await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(10, units='ns')