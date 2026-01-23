import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess
import random

# Helper to convert string to byte (ASCII)
def str_to_byte(s):
    return ord(s[0]) if s else 0

@cocotb.test()
async def test_council_solver_basic(dut):
    """Test the basic functionality: 3 residents, 3 clubs, party constraint"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_residents.value = 0
    dut.num_clubs.value = 0
    dut.load_valid.value = 0
    dut.resident_id.value = 0
    dut.party_id.value = 0
    dut.club_mask.value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Configuration
    dut.num_residents.value = 3
    dut.num_clubs.value = 3
    await RisingEdge(dut.clk)
    
    # Load Residents
    # Resident 1: 'A' (Party '1'), Clubs {0, 1} -> mask 0011 (bits 0 and 1)
    dut.resident_id.value = str_to_byte('A')
    dut.party_id.value = str_to_byte('1')
    dut.club_mask.value = 0b0011
    dut.load_valid.value = 1
    await RisingEdge(dut.clk)
    
    # Resident 2: 'B' (Party '2'), Clubs {0, 2} -> mask 0101
    dut.resident_id.value = str_to_byte('B')
    dut.party_id.value = str_to_byte('2')
    dut.club_mask.value = 0b0101
    await RisingEdge(dut.clk)
    
    # Resident 3: 'C' (Party '2'), Clubs {1, 2} -> mask 0110
    dut.resident_id.value = str_to_byte('C')
    dut.party_id.value = str_to_byte('2')
    dut.club_mask.value = 0b0110
    await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Start Solving
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for solution or impossible
    # The problem allows any solution. 
    # In this case: 
    # Club 0 can be A or B
    # Club 1 can be A or C
    # Club 2 can be B or C
    # Constraint: 3 members. Party 2 must have < 2 members (max 1). Party 1 must have < 2 (max 1).
    # So we need exactly 1 Party 1 and 2 Party 2 is INVALID. 2 Party 1 is INVALID.
    # We need 1 Party 1 (A) and 2 Party 2. But 2 Party 2 is not < 1.5. Wait.
    # 3 members. Half is 1.5. Members must be strictly less than 1.5? No, "does not equal or exceed half".
    # Half of 3 is 1.5. Exceed 1.5 means >= 2.
    # So Party 2 must have count <= 1.
    # Party 1 must have count <= 1.
    # But total is 3. Impossible? 
    # Wait, 1 + 1 = 2. We are missing a member.
    # This test case might be Impossible. Let's check.
    # 3 members. Party 1: max 1. Party 2: max 1. Total max 2. Need 3. IMPOSSIBLE.
    # I need to fix the test case to be solvable.
    
    # Let's restart the test with a solvable scenario.
    # Re-assert reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Try 4 residents, 4 clubs.
    # Party balance: < 4/2 = 2. So max 1 per party.
    # We need 4 members from 4 parties (or clever assignment).
    # Let's define:
    # Club 0: Residents A, B
    # Club 1: Residents C, D
    # Club 2: Residents A, D
    # Club 3: Residents B, C
    # Party A: 1, Party B: 1, Party C: 1, Party D: 1. Valid.
    
    dut.num_residents.value = 4
    dut.num_clubs.value = 4
    await RisingEdge(dut.clk)
    
    # Load
    # A (Party 1): Mask 1001 (C0, C3)
    dut.resident_id.value = str_to_byte('A')
    dut.party_id.value = str_to_byte('1')
    dut.club_mask.value = 0b1001
    dut.load_valid.value = 1
    await RisingEdge(dut.clk)
    
    # B (Party 2): Mask 0101 (C0, C2)
    dut.resident_id.value = str_to_byte('B')
    dut.party_id.value = str_to_byte('2')
    dut.club_mask.value = 0b0101
    await RisingEdge(dut.clk)
    
    # C (Party 3): Mask 0110 (C1, C2)
    dut.resident_id.value = str_to_byte('C')
    dut.party_id.value = str_to_byte('3')
    dut.club_mask.value = 0b0110
    await RisingEdge(dut.clk)
    
    # D (Party 4): Mask 1010 (C1, C3)
    dut.resident_id.value = str_to_byte('D')
    dut.party_id.value = str_to_byte('4')
    dut.club_mask.value = 0b1010
    await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for solution
    cycles = 0
    while not (dut.solved.value or dut.impossible.value) and cycles < 2000:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles == 1999:
            raise TestFailure("Simulation timed out")
            
    if dut.impossible.value:
        raise TestFailure("Should be possible, but got Impossible")
    
    if not dut.solved.value:
        raise TestFailure("Did not assert solved")
        
    # Collect results
    assignments = []
    for _ in range(4):
        await RisingEdge(dut.clk)
        if dut.result_valid.value:
            club = chr(dut.result_club_id.value)
            res = chr(dut.result_resident_id.value)
            assignments.append((res, club))
            dut._log.info(f"Assignment: {res} -> {club}")
    
    # Verify validity
    assigned_clubs = set()
    assigned_residents = set()
    party_counts = {}
    
    for res, club in assignments:
        if club in assigned_clubs:
            raise TestFailure(f"Club {club} assigned twice")
        if res in assigned_residents:
            raise TestFailure(f"Resident {res} assigned twice")
        assigned_clubs.add(club)
        assigned_residents.add(res)
        
        # Map resident to party (hardcoded based on our load)
        party = ''
        if res == 'A': party = '1'
        elif res == 'B': party = '2'
        elif res == 'C': party = '3'
        elif res == 'D': party = '4'
        
        if party in party_counts:
            party_counts[party] += 1
        else:
            party_counts[party] = 1
            
    for p, count in party_counts.items():
        if count >= 2: # 4 clubs, limit is < 2
            raise TestFailure(f"Party {p} has {count} members, limit is < 2")
            
    print(f"Test Passed. Found valid assignment: {assignments}")

@cocotb.test()
async def test_council_solver_impossible(dut):
    """Test impossible case: 3 residents, 3 clubs, impossible constraint"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Config: 3 residents, 3 clubs
    # Constraint: < 1.5 -> max 1 per party
    # If we have 2 parties, we can have max 2 residents. We need 3. Impossible.
    
    dut.num_residents.value = 3
    dut.num_clubs.value = 3
    await RisingEdge(dut.clk)
    
    # Resident A (Party 1), Clubs 0, 1
    dut.resident_id.value = str_to_byte('A')
    dut.party_id.value = str_to_byte('1')
    dut.club_mask.value = 0b0011
    dut.load_valid.value = 1
    await RisingEdge(dut.clk)
    
    # Resident B (Party 1), Clubs 0, 2
    dut.resident_id.value = str_to_byte('B')
    dut.party_id.value = str_to_byte('1')
    dut.club_mask.value = 0b0101
    await RisingEdge(dut.clk)
    
    # Resident C (Party 2), Clubs 1, 2
    dut.resident_id.value = str_to_byte('C')
    dut.party_id.value = str_to_byte('2')
    dut.club_mask.value = 0b0110
    await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    cycles = 0
    while not (dut.solved.value or dut.impossible.value) and cycles < 2000:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles == 1999:
            raise TestFailure("Simulation timed out")
            
    if not dut.impossible.value:
        raise TestFailure("Should be impossible")
        
    print("Test Passed. Correctly identified impossible case.")