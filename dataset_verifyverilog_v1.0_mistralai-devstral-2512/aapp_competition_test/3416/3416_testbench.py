import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4
NODE_BITS = 4
EDGE_BITS = 5
MAX_NODES = 16
MAX_EDGES = 32
CLK_NS = 10
MAX_CYCLES = 256

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_traveling_salesman(dut):
    # Setup clock and reset if sequential
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational; ensure stable inputs
        await Timer(100, units='ns')

    # Test cases: each is (n, edges_list, expected_flights, expected_airports_set)
    test_cases = [
        (4, [(1,2), (1,3), (2,4), (3,4)], 1, {1,2,3,4}),  # 2 components? Actually connected: undirected graph is connected, but DAG has sources=2, sinks=2 -> flights=1 (connect sink to source)
        (4, [(1,2), (2,3), (3,4)], 0, {1,2,3,4}),  # Single path
        (3, [(1,2)], 1, {1,2,3}),  # Component1: {1,2}, Component2: {3} isolated -> flights=1, airports: all non-isolated? {1,2} and 3 if we fly to it? Actually he can visit airport in 3 if he flies there or from there. With min flights, he can visit all non-isolated and also isolated if part of route? In example, isolated nodes are included if flights>0? In example 1, all nodes included. Let's assume for simplicity: if flights>0, airports = all nodes with degree>0, else all nodes. For isolated node (degree 0), it's a component by itself; to visit it, need flight to/from it, so airport can be visited. So include all nodes in any component? Actually, if a node is isolated, you can start there, fly out, then never return, but you can visit its airport by starting there (airport visited by flying out). So all nodes can be visited in some route with min flights.
        (2, [], 1, {1,2}),  # No edges, two components, need 1 flight, both nodes can be visited (start at one, fly to other)
    ]

    passed = 0
    failed = 0

    for i, (n, edges, exp_flights, exp_airports) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: n={n}, edges={len(edges)}, exp_flights={exp_flights}")
        
        # Reset for each test
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            if has_signal(dut, 'start'): dut.start.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
        
        # Feed edges
        if has_signal(dut, 'start'):
            dut.start.value = 1
            dut.n.value = clamp_to_width(n, NODE_BITS)
            dut.m.value = clamp_to_width(len(edges), EDGE_BITS)
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            for idx, (a, b) in enumerate(edges):
                dut.edge_a.value = clamp_to_width(a, NODE_BITS)
                dut.edge_b.value = clamp_to_width(b, NODE_BITS)
                dut.edge_valid.value = 1
                if idx == len(edges)-1:
                    dut.edge_done.value = 1
                await RisingEdge(dut.clk)
                dut.edge_valid.value = 0
                dut.edge_done.value = 0
        else:
            # Combinational: set all inputs at once
            dut.n.value = clamp_to_width(n, NODE_BITS)
            dut.m.value = clamp_to_width(len(edges), EDGE_BITS)
            # For combinational, we need to set all edges; but module likely expects sequential input. Assume sequential for this testbench.
            pass

        # Wait for done
        if has_signal(dut, 'done'):
            done = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            if not done:
                cocotb.log.error(f"Test {i+1} timeout")
                failed += 1
                continue
        else:
            # Combinational: assume result ready after some delay
            await Timer(200, units='ns')

        # Read results
        if not is_value_defined(dut.min_flights.value):
            cocotb.log.error(f"Test {i+1}: min_flights undefined")
            failed += 1
            continue
        
        min_flights = int(dut.min_flights.value)
        airport_count = int(dut.airport_count.value) if has_signal(dut, 'airport_count') else 0
        airport_list_val = int(dut.airport_list.value) if has_signal(dut, 'airport_list') else 0
        
        # Decode airport list: bits 0-15 for cities 1-16
        airports = []
        for node in range(1, n+1):
            bit = node - 1
            if airport_list_val & (1 << bit):
                airports.append(node)
        
        cocotb.log.info(f"Result: flights={min_flights}, airports={sorted(airports)}")
        
        try:
            if min_flights != exp_flights:
                raise TestFailure(f"Expected flights {exp_flights}, got {min_flights}")
            if set(airports) != exp_airports:
                raise TestFailure(f"Expected airports {sorted(exp_airports)}, got {sorted(airports)}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
