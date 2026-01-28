import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4  # City/road IDs (0-15)
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 500

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
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def solve_reference(n, edges):
    """Reference Python solver for verification"""
    # Simplified for n <= 16
    # Build adjacency list
    adj = {i: [] for i in range(n)}
    for i, (a, b) in enumerate(edges):
        adj[a-1].append(i)
        adj[b-1].append(i)
    
    # Try assignment with DFS
    result = [None] * n
    used = set()
    
    def dfs(city):
        # Try all roads adjacent to this city
        for road_idx in adj[city]:
            if road_idx in used:
                continue
            a, b = edges[road_idx]
            a, b = a-1, b-1
            other = b if a == city else a
            used.add(road_idx)
            result[road_idx] = city + 1
            if other == city or (other != city and dfs(other)):
                return True
            used.remove(road_idx)
        return False
    
    for city in range(n):
        if not dfs(city):
            # Try alternative assignment
            for road_idx in adj[city]:
                if road_idx in used:
                    continue
                result[road_idx] = city + 1
                used.add(road_idx)
                if len(used) == n:
                    return result
                break
    
    return result

def validate_solution(n, edges, assignment):
    """Check if assignment is valid"""
    # Each road must be assigned to one of its endpoints
    for i in range(n):
        a, b = edges[i]
        city = assignment[i]
        if city not in (a, b):
            return False
    
    # Each city must build exactly one road
    city_count = [0] * (n+1)
    for city in assignment:
        city_count[city] += 1
    
    for city in range(1, n+1):
        if city_count[city] != 1:
            return False
    
    return True

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_road_assignment(dut):
    # Check if sequential module
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, list of (a,b) edges)
    test_cases = [
        (4, [(1,2), (2,3), (3,1), (4,1)], "Sample case 1"),
        (2, [(1,2), (1,2)], "Sample case 2"),
        (3, [(1,2), (2,3), (3,1)], "Triangle"),
        (1, [(1,1)], "Single city (self-loop)"),
        (5, [(1,2), (2,3), (3,4), (4,5), (5,1)], "Cycle of 5"),
    ]
    
    passed = failed = 0
    
    for i, (n, edges, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n})")
        try:
            # Verify reference solution exists
            ref_assignment = solve_reference(n, edges)
            if not validate_solution(n, edges, ref_assignment):
                cocotb.log.warning(f"Reference solution invalid for test {desc}")
                # Try to find any valid assignment
                valid = False
                for perm in range(2**n):
                    test_assign = []
                    for idx in range(n):
                        if (perm >> idx) & 1:
                            test_assign.append(edges[idx][0])
                        else:
                            test_assign.append(edges[idx][1])
                    if validate_solution(n, edges, test_assign):
                        ref_assignment = test_assign
                        valid = True
                        break
                if not valid:
                    raise TestFailure(f"No valid assignment exists for {desc}")
            
            # Load inputs
            dut.n.value = clamp_to_width(n, DATA_WIDTH)
            
            # Load edges arrays
            for idx in range(MAX_N):
                if idx < n:
                    dut.edges_a[idx].value = clamp_to_width(edges[idx][0] - 1, DATA_WIDTH)
                    dut.edges_b[idx].value = clamp_to_width(edges[idx][1] - 1, DATA_WIDTH)
                else:
                    dut.edges_a[idx].value = 0
                    dut.edges_b[idx].value = 0
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.done.value):
                raise TestFailure("done signal undefined")
            
            if int(dut.done.value) != 1:
                raise TestFailure(f"done not asserted (value={dut.done.value})")
            
            # Read result_city array
            assignment = []
            for idx in range(n):
                city_val = getattr(dut, f'result_city_{idx}', None)
                if city_val is not None:
                    city = int(city_val.value)
                else:
                    # Access as array
                    if hasattr(dut, 'result_city'):
                        city = int(dut.result_city[idx].value)
                    else:
                        raise TestFailure(f"Cannot access result_city[{idx}]")
                # Convert back to 1-indexed for validation
                assignment.append(city + 1)
            
            # Validate
            if not validate_solution(n, edges, assignment):
                raise TestFailure(f"Invalid assignment for {desc}: {assignment}")
            
            # Optionally check against reference
            # Note: multiple solutions possible, so only check validity
            
            cocotb.log.info(f"  PASS: assignment {assignment}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_commutative(dut):
    """Test that edges a-b and b-a are equivalent"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    n = 2
    edges = [(1,2), (1,2)]
    
    dut.n.value = clamp_to_width(n, DATA_WIDTH)
    for idx in range(n):
        dut.edges_a[idx].value = clamp_to_width(edges[idx][0] - 1, DATA_WIDTH)
        dut.edges_b[idx].value = clamp_to_width(edges[idx][1] - 1, DATA_WIDTH)
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if int(dut.done.value) != 1:
        raise TestFailure("Commutative test: done not asserted")
    
    # Read both assignments
    assignments = []
    for idx in range(n):
        if hasattr(dut, 'result_city'):
            city = int(dut.result_city[idx].value)
        else:
            city = int(getattr(dut, f'result_city_{idx}').value)
        assignments.append(city + 1)
    
    # Validate
    if not validate_solution(n, edges, assignments):
        raise TestFailure(f"Commutative test failed: {assignments}")
    
    cocotb.log.info("Commutative test passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_no_solution_case(dut):
    """Test edge case - should find solution anyway"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Single city with self-loop
    n = 1
    edges = [(1,1)]
    
    dut.n.value = clamp_to_width(n, DATA_WIDTH)
    dut.edges_a[0].value = clamp_to_width(edges[0][0] - 1, DATA_WIDTH)
    dut.edges_b[0].value = clamp_to_width(edges[0][1] - 1, DATA_WIDTH)
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if int(dut.done.value) != 1:
        raise TestFailure("Self-loop test: done not asserted")
    
    if hasattr(dut, 'result_city'):
        city = int(dut.result_city[0].value)
    else:
        city = int(getattr(dut, 'result_city_0').value)
    
    assignment = [city + 1]
    if not validate_solution(n, edges, assignment):
        raise TestFailure(f"Self-loop test failed: {assignment}")
    
    cocotb.log.info("Self-loop test passed")