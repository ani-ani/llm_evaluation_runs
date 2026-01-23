import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import random

async def check_schedule(dut, n, m):
    """Helper to verify the generated schedule meets constraints."""
    dut.n_in.value = n
    dut.m_in.value = m
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    total_players = n * m
    max_rounds = (m - 1) * n + 1
    
    rounds = []
    
    # Wait for output or done
    timeout = 0
    while not dut.done.value and timeout < 2000:
        if dut.output_valid.value:
            p1 = dut.player1_idx.value
            p2 = dut.player2_idx.value
            # Determine team
            t1 = p1 // n
            t2 = p2 // n
            
            # Check valid indices
            assert 0 <= p1 < total_players, f"Player1 index {p1} out of range"
            assert 0 <= p2 < total_players, f"Player2 index {p2} out of range"
            
            # Check different teams
            assert t1 != t2, f"Players {p1} and {p2} are in same team {t1}"
            
            # Add to current round
            if len(rounds) == 0:
                rounds.append([])
            rounds[-1].append((p1, p2))
            
        await RisingEdge(dut.clk)
        
        # Check if new round started (round_index incremented)
        # This is tricky to detect purely from outputs, but we track done.
        # The design should output all games for a round, then increment.
        # We can detect a pause in output_valid as a separator, or done.
        
        # Simple tracking:
        if dut.round_index.value > 0 and len(rounds) == dut.round_index.value:
             # Round just finished
             pass
             
        timeout += 1
        
    # Final round check
    # Note: The round_index in output tracks the CURRENT round being generated or the LAST generated?
    # The spec says "Current round number". 
    # Let's assume the design outputs all rounds, then done.
    # We need to capture rounds as they come.
    
    # To properly parse rounds, we need to know when a round ends.
    # Since game_count is 'Number of games in current round', maybe it decrements or we just count valid cycles?
    # Let's assume we just collect all valid games and check constraints on the set.
    
    # Re-simulation: The design should output games grouped by round.
    # We can look at `round_index` change to know when a round ends.
    
    # Let's restart the capture logic to be robust:
    rounds = []
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    curr_round = -1
    game_list = []
    
    # Wait for first valid or done
    for _ in range(1000):
        if dut.done.value:
            break
        if dut.output_valid.value:
            r_idx = int(dut.round_index.value)
            if r_idx != curr_round:
                if curr_round != -1:
                    rounds.append(game_list)
                game_list = []
                curr_round = r_idx
            game_list.append((int(dut.player1_idx.value), int(dut.player2_idx.value)))
        await RisingEdge(dut.clk)
    
    if curr_round != -1:
        rounds.append(game_list)
        
    print(f"Generated {len(rounds)} rounds (max {max_rounds})")
    
    assert len(rounds) <= max_rounds, f"Too many rounds: {len(rounds)} > {max_rounds}"
    
    # Verification 1: Everyone plays everyone from other teams
    required_matches = set()
    for t in range(m):
        for p in range(n):
            p_idx = t * n + p
            for t2 in range(m):
                if t == t2: continue
                for p2 in range(n):
                    p2_idx = t2 * n + p2
                    # Order independent set
                    if p_idx < p2_idx:
                        required_matches.add((p_idx, p2_idx))
                    else:
                        required_matches.add((p2_idx, p_idx))
    
    found_matches = set()
    byes = {}
    for r_idx, r in enumerate(rounds):
        played_in_round = set()
        for (p1, p2) in r:
            # Check valid pair
            assert p1 != p2, "Player playing self"
            
            key = tuple(sorted((p1, p2)))
            assert key not in found_matches, f"Duplicate match {key}"
            found_matches.add(key)
            
            played_in_round.add(p1)
            played_in_round.add(p2)
        
        # Check no player plays twice in a round
        assert len(played_in_round) == len(r) * 2, "Player played twice in one round"
        
        # Track byes
        for pid in range(total_players):
            if pid not in played_in_round:
                byes[pid] = byes.get(pid, 0) + 1
    
    # Check all matches played
    assert found_matches == required_matches, "Missing matches"
    
    # Check byes
    for pid, count in byes.items():
        assert count <= 1, f"Player {pid} had {count} byes"
    
    print(f"All checks passed! {len(found_matches)} matches in {len(rounds)} rounds.")

@cocotb.test()
async def test_tournament_1(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await check_schedule(dut, 3, 2) # 6 players

@cocotb.test()
async def test_tournament_2(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await check_schedule(dut, 2, 3) # 6 players

@cocotb.test()
async def test_tournament_3(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await check_schedule(dut, 1, 5) # 5 players
