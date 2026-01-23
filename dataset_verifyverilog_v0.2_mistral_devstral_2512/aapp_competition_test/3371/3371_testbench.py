import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure, TestSuccess

# Helper function to convert year to offset
def year_to_offset(year):
    return year - 1948

def check_partition_size(n, group_a_size):
    """Check if group sizes are valid: max size <= 2*n/3"""
    group_b_size = n - group_a_size
    max_allowed = (2 * n) // 3
    return max(group_a_size, group_b_size) <= max_allowed

def solve_golden(encounters, n):
    """Find smallest valid year using Python (reference)"""
    # If all pairs met in same year, impossible or need Y > max_year or Y <= min_year
    years = sorted(set(y for a, b, y in encounters))
    if not years:
        # No encounters - any year works, return 1949 (offset 1)
        return 1949
    
    # Try each year threshold Y
    # For threshold Y: pairs with meeting_year < Y go to Group A, >= Y go to Group B
    # Groups must satisfy size constraint and all pairs within group must have valid meeting years
    
    all_years = [1948] + years + [2008]
    
    for Y in range(1948, 2009):
        # Build adjacency matrix for 'same group' constraints
        # If two people are linked in same component, they must be in same group
        parent = list(range(n+1))
        
        def find(x):
            if parent[x] != x:
                parent[x] = find(parent[x])
            return parent[x]
        
        def union(x, y):
            px, py = find(x), find(y)
            if px != py:
                parent[px] = py
        
        # Add constraints: all pairs that must be together
        for a, b, y in encounters:
            if y < Y:
                # must be together in group A
                union(a, b)
            elif y >= Y:
                # must be together in group B
                union(a, b)
        
        # Count components
        components = {}
        for i in range(1, n+1):
            root = find(i)
            if root not in components:
                components[root] = []
            components[root].append(i)
        
        # Try to assign components to groups to satisfy size constraint
        comp_sizes = [len(comp) for comp in components.values()]
        num_comps = len(comp_sizes)
        
        # Simple DP or brute force for small num_comps (max 16)
        def can_partition(idx, size_a):
            if idx == num_comps:
                return check_partition_size(n, size_a)
            # Try assigning to A
            if can_partition(idx + 1, size_a + comp_sizes[idx]):
                return True
            # Try assigning to B
            if can_partition(idx + 1, size_a):
                return True
            return False
        
        if can_partition(0, 0):
            return Y
    
    return None

@cocotb.test()
async def test_partition_divider(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Impossible (all pairs met in 1987)
    # 4 participants, 6 edges, all year 39 (1987-1948)
    # With n=4, 2/3*4 = 2.66 -> max 2 per group
    # All pairs met in 1987, so:
    # - Y > 1987: all in Group B, size 4 > 2, invalid
    # - Y <= 1987: all in Group A, size 4 > 2, invalid
    # So impossible
    
    dut.n.value = 4
    dut.c.value = 6
    encounters1 = [(1,2,39), (1,3,39), (1,4,39), (2,3,39), (2,4,39), (3,4,39)]
    for i in range(6):
        dut.a[i].value = encounters1[i][0]
        dut.b[i].value = encounters1[i][1]
        dut.year[i].value = encounters1[i][2]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.result_impossible.value != 1:
        raise TestFailure(f"Test 1: Expected impossible=1, got {dut.result_impossible.value}")
    print("Test 1 passed: Correctly detected impossible case")
    
    # Test Case 2: Valid year exists
    # 6 participants, 3 edges: (1,2) in 1970, (3,4) in 1980, (5,6) in 1990
    # Year 1971 (offset 23):
    # - (1,2) met in 1970 < 1971 -> must be together -> Group A (size 2)
    # - (3,4) met in 1980 >= 1971 -> must be together -> Group B (size 2)
    # - (5,6) met in 1990 >= 1971 -> must be together -> Group B (size 4 total)
    # - Participants 1,2,3,4,5,6: components {1,2}, {3,4}, {5,6}
    # Try: {1,2} in A (size 2), {3,4,5,6} in B (size 4)
    # Max size = 4, 2/3*6 = 4, OK!
    # So Y=1971 works
    # But wait, let's check smaller Y: Y=1970
    # (1,2) >= 1970 -> B, (3,4) >= 1970 -> B, (5,6) >= 1970 -> B
    # All in B, size 6, 2/3*6=4 -> 6>4 invalid
    # Y=1949:
    # (1,2) >= 1949 -> B, etc. All in B, invalid
    # So 1971 is smallest
    
    dut.n.value = 6
    dut.c.value = 3
    encounters2 = [(1,2,22), (3,4,32), (5,6,42)]  # 1970-1948=22, 1980-1948=32, 1990-1948=42
    for i in range(3):
        dut.a[i].value = encounters2[i][0]
        dut.b[i].value = encounters2[i][1]
        dut.year[i].value = encounters2[i][2]
    
    # Fill rest with zeros
    for i in range(3, 16):
        dut.a[i].value = 0
        dut.b[i].value = 0
        dut.year[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.result_impossible.value != 0:
        raise TestFailure(f"Test 2: Expected impossible=0, got {dut.result_impossible.value}")
    if dut.result_year.value != 23:  # 1971-1948 = 23
        raise TestFailure(f"Test 2: Expected year 23, got {dut.result_year.value}")
    print("Test 2 passed: Found correct year 1971")
    
    # Test Case 3: No edges (all participants separate)
    # n=5, c=0
    # Any Y works. Smallest is 1948.
    # But wait: For Y=1948:
    # All pairs met in 2008 (default) >= 1948 -> Group B
    # So all in B, size 5, 2/3*5=3.33->3, 5>3 invalid
    # For Y=2008:
    # All pairs met in 2008 < 2008? No, 2008 == 2008 -> >= 2008 -> B
    # Hmm, for Y=2009 (offset 61, outside range)
    # Let's recheck logic:
    # Y=1949: pairs met in 2008 >= 1949 -> Group B
    # We need a Y where we can partition into two groups of size <= 3
    # With no constraints, we can just put any split.
    # But we need all pairs within group to satisfy condition:
    # Group A: met before Y. Since all met in 2008, if Y > 2008, then all met < Y -> A. Size 5 invalid.
    # If Y <= 2008, all met >= Y -> B. Size 5 invalid.
    # So wait, for n=5, 2/3*5 = 3. So max group size 3.
    # But with no edges, we have 5 isolated vertices.
    # We can put 3 in A, 2 in B.
    # Condition: all pairs in A met < Y. Since there are no pairs in A, vacuously true.
    # Similarly for B. So any Y works.
    # But wait, if we have 5 people, we split 3 and 2.
    # For the split to be valid, there must be NO edges between the split.
    # With 0 edges, any split is valid.
    # So we can pick Y=1948.
    # Wait, but my earlier logic said all isolated -> 5 components.
    # We can assign 3 components to A, 2 to B.
    # So Y=1948 should work.
    # But Y=1948 means: pairs meeting < 1948 in A, >= 1948 in B.
    # With 0 edges, we have 5 isolated nodes. We can choose partition {1,2,3} and {4,5}.
    # This satisfies the requirement.
    # So Y=1948 is valid.
    # But wait, 1948 is offset 0.
    # However, the sample logic in Python test case might be slightly different.
    # Let me double check the Python solver on n=5, c=0.
    # Y=1948 (offset 0).
    # Encounters: none.
    # Constraint graph: 5 isolated vertices.
    # Can we partition into sizes <= 2 (since 2/3*5=3.33, max 3).
    # Yes, 3 and 2.
    # So Y=1948 works.
    # Smallest year.
    
    dut.n.value = 5
    dut.c.value = 0
    for i in range(16):
        dut.a[i].value = 0
        dut.b[i].value = 0
        dut.year[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.result_impossible.value != 0:
        raise TestFailure(f"Test 3: Expected impossible=0, got {dut.result_impossible.value}")
    # Python solver returns 1948 (offset 0) for n=5, c=0
    if dut.result_year.value != 0:
        raise TestFailure(f"Test 3: Expected year 0, got {dut.result_year.value}")
    print("Test 3 passed: Correct year 1948 for empty edges")
    
    # Test Case 4: Chain graph
    # n=4, edges: 1-2(1950), 2-3(1950), 3-4(1950)
    # Y=1951 (offset 3):
    # All edges < 1951, so all 4 must be together -> Group A. Size 4 > 2 invalid.
    # Y=1950 (offset 2):
    # All edges >= 1950, so all 4 must be together -> Group B. Size 4 > 2 invalid.
    # So impossible? Not necessarily.
    # Wait, edges are only 1-2, 2-3, 3-4.
    # So constraint graph is a path 1-2-3-4.
    # This is connected, so all must be same group.
    # Size 4 > 2.66 -> 2. So invalid.
    # So impossible.
    
    dut.n.value = 4
    dut.c.value = 3
    encounters4 = [(1,2,2), (2,3,2), (3,4,2)]  # 1950-1948=2
    for i in range(3):
        dut.a[i].value = encounters4[i][0]
        dut.b[i].value = encounters4[i][1]
        dut.year[i].value = encounters4[i][2]
    for i in range(3, 16):
        dut.a[i].value = 0
        dut.b[i].value = 0
        dut.year[i].value = 0
        
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.result_impossible.value != 1:
        raise TestFailure(f"Test 4: Expected impossible=1, got {dut.result_impossible.value}")
    print("Test 4 passed: Correctly detected impossible chain case")
    
    # Test Case 5: Two separate groups
    # n=4, edges: 1-2(1950), 3-4(1980)
    # Y=1980 (offset 32):
    # 1-2 < 1980 -> A, 3-4 >= 1980 -> B.
    # Split: {1,2} size 2, {3,4} size 2. Max=2, 2/3*4=2.66->2. OK.
    # Smallest?
    # Y=1951: 1-2 < 1951 -> A, 3-4 >= 1951 -> B. Split works.
    # ...
    # Y=1950: 1-2 >= 1950 -> B, 3-4 >= 1950 -> B. All in B, size 4 > 2. Invalid.
    # Y=1949: Same as Y=1950. Invalid.
    # Y=1951 works.
    # Offset 3.
    
    dut.n.value = 4
    dut.c.value = 2
    encounters5 = [(1,2,2), (3,4,32)]
    for i in range(2):
        dut.a[i].value = encounters5[i][0]
        dut.b[i].value = encounters5[i][1]
        dut.year[i].value = encounters5[i][2]
    for i in range(2, 16):
        dut.a[i].value = 0
        dut.b[i].value = 0
        dut.year[i].value = 0
        
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.result_impossible.value != 0:
        raise TestFailure(f"Test 5: Expected impossible=0, got {dut.result_impossible.value}")
    if dut.result_year.value != 3:
        raise TestFailure(f"Test 5: Expected year 3, got {dut.result_year.value}")
    print("Test 5 passed: Correct year 1951")
    
    print("All 5 tests passed!")
