import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# REFERENCE SCHEDULE GENERATOR (Greedy Algorithm)
# ============================================================================

def generate_schedule(n, m):
    total_players = n * m
    # played[i][j] = True if i and j have played
    played = [[False] * total_players for _ in range(total_players)]
    remaining = [(m - 1) * n] * total_players
    rounds = []
    
    while any(remaining[i] > 0 for i in range(total_players)):
        round_games = []
        scheduled = [False] * total_players
        progress = False
        
        for i in range(total_players):
            if scheduled[i] or remaining[i] == 0:
                continue
            for j in range(total_players):
                if i == j:
                    continue
                team_i = i // n
                team_j = j // n
                if team_i == team_j:
                    continue
                if scheduled[j] or played[i][j] or remaining[j] == 0:
                    continue
                # Schedule game
                round_games.append((i, j))
                scheduled[i] = True
                scheduled[j] = True
                played[i][j] = True
                played[j][i] = True
                remaining[i] -= 1
                remaining[j] -= 1
                progress = True
                break
        
        if not progress:
            break
        rounds.append(round_games)
    
    return rounds

def player_to_str(pid, n):
    team = pid // n
    player = pid % n
    return f"{chr(ord('A') + team)}{player + 1}"

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_schedule(dut):
    # Test parameters
    test_cases = [
        (3, 2),
        (2, 3),
        (1, 5),
        (2, 2),
        (4, 3)
    ]
    
    for n, m in test_cases:
        dut._log.info(f"Testing n={n}, m={m}")
        
        # Configure DUT
        dut.n.value = n
        dut.m.value = m
        
        # Start clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset
        await reset_dut(dut)
        
        # Generate reference schedule
        ref_schedule = generate_schedule(n, m)
        dut._log.info(f"Reference schedule: {len(ref_schedule)} rounds")
        
        # Start the generator
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Capture output
        current_round = 0
        round_games = []
        all_games = []
        timeout_counter = 0
        MAX_OUTPUT_CYCLES = 10000
        
        while timeout_counter < MAX_OUTPUT_CYCLES:
            await RisingEdge(dut.clk)
            timeout_counter += 1
            
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            
            if has_signal(dut, 'valid') and is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                if not is_value_defined(dut.round.value) or not is_value_defined(dut.p1.value) or not is_value_defined(dut.p2.value):
                    raise TestFailure(f"Undefined output at cycle {timeout_counter}")
                
                round_num = int(dut.round.value)
                p1 = int(dut.p1.value)
                p2 = int(dut.p2.value)
                
                if round_num != current_round:
                    if round_games:
                        all_games.append(round_games)
                    round_games = []
                    current_round = round_num
                
                round_games.append((p1, p2))
        
        if round_games:
            all_games.append(round_games)
        
        # Verify results
        if len(all_games) != len(ref_schedule):
            raise TestFailure(f"Round count mismatch: {len(all_games)} vs {len(ref_schedule)}")
        
        for r, (out_round, ref_round) in enumerate(zip(all_games, ref_schedule)):
            if len(out_round) != len(ref_round):
                raise TestFailure(f"Round {r}: game count mismatch: {len(out_round)} vs {len(ref_round)}")
            
            out_set = set((min(p1,p2), max(p1,p2)) for p1,p2 in out_round)
            ref_set = set((min(p1,p2), max(p1,p2)) for p1,p2 in ref_round)
            
            if out_set != ref_set:
                out_str = ' '.join(sorted(f"{player_to_str(p1,n)}-{player_to_str(p2,n)}" for p1,p2 in out_round))
                ref_str = ' '.join(sorted(f"{player_to_str(p1,n)}-{player_to_str(p2,n)}" for p1,p2 in ref_round))
                raise TestFailure(f"Round {r} mismatch:\nGot: {out_str}\nRef: {ref_str}")
        
        dut._log.info(f"PASSED: n={n}, m={m} - {len(all_games)} rounds")
        
        # Wait before next test
        await Timer(100, units='ns')
        
    dut._log.info("All tests completed successfully!")