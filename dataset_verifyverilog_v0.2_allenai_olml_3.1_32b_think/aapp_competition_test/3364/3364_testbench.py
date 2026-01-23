import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

class DSUReference:
    def __init__(self, n=8):
        self.parent = list(range(n))
    
    def find(self, x):
        if self.parent[x] != x:
            self.parent[x] = self.find(self.parent[x])
        return self.parent[x]
    
    def union(self, x, y):
        root_x = self.find(x)
        root_y = self.find(y)
        if root_x != root_y:
            self.parent[root_x] = root_y
    
    def query(self, x, y):
        return self.find(x) == self.find(y)

@cocotb.test()
async def test_dsu_basic(dut):
    """Test basic DSU operations: union and query"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    ref = DSUReference(8)
    
    # Test 1: Query 1 and 3 (should be no)
    dut.op_type.value = 1  # query
    dut.a.value = 1
    dut.b.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Test 1: Operation did not complete in time")
    
    expected = ref.query(1, 3)
    actual = int(dut.result.value)
    if actual != expected:
        raise TestFailure(f"Test 1: Expected {expected}, got {actual}")
    print(f"Test 1 Query (1,3): {'yes' if actual else 'no'} - PASS")
    
    # Test 2: Union 1 and 8 (but we only have 0-7, use 1 and 4)
    dut.op_type.value = 0  # union
    dut.a.value = 1
    dut.b.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Test 2: Operation did not complete in time")
    
    ref.union(1, 4)
    print(f"Test 2 Union (1,4): Done")
    
    # Test 3: Union 3 and 4
    dut.op_type.value = 0  # union
    dut.a.value = 3
    dut.b.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Test 3: Operation did not complete in time")
    
    ref.union(3, 4)
    print(f"Test 3 Union (3,4): Done")
    
    # Test 4: Query 1 and 3 (should be yes)
    dut.op_type.value = 1  # query
    dut.a.value = 1
    dut.b.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Test 4: Operation did not complete in time")
    
    expected = ref.query(1, 3)
    actual = int(dut.result.value)
    if actual != expected:
        raise TestFailure(f"Test 4: Expected {expected}, got {actual}")
    print(f"Test 4 Query (1,3): {'yes' if actual else 'no'} - PASS")
    
    print("
All tests passed!")

@cocotb.test()
async def test_dsu_complex(dut):
    """Test complex DSU operations with path compression"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    ref = DSUReference(8)
    
    # Create chain: 0->1->2->3, then 4->5->6->7
    operations = [
        (0, 1), (1, 2), (2, 3),  # First chain
        (4, 5), (5, 6), (6, 7),  # Second chain
    ]
    
    for a, b in operations:
        dut.op_type.value = 0  # union
        dut.a.value = a
        dut.b.value = b
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for _ in range(30):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        ref.union(a, b)
        print(f"Union ({a},{b}): Done")
    
    # Now join chains
    dut.op_type.value = 0  # union
    dut.a.value = 0
    dut.b.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    ref.union(0, 4)
    print(f"Union (0,4): Done")
    
    # Test queries
    test_cases = [(0, 3), (4, 7), (0, 7), (1, 6), (0, 5)]
    
    for a, b in test_cases:
        dut.op_type.value = 1  # query
        dut.a.value = a
        dut.b.value = b
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done = False
        for _ in range(30):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Query ({a},{b}) did not complete")
        
        expected = ref.query(a, b)
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Query ({a},{b}): Expected {expected}, got {actual}")
        print(f"Query ({a},{b}): {'yes' if actual else 'no'} - PASS")
    
    print("
Complex tests passed!")

@cocotb.test()
async def test_dsu_edge_cases(dut):
    """Test edge cases: same element, isolated nodes, path compression verification"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    ref = DSUReference(8)
    
    # Test 1: Query same element
    dut.op_type.value = 1
    dut.a.value = 5
    dut.b.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    expected = ref.query(5, 5)
    actual = int(dut.result.value)
    if actual != expected:
        raise TestFailure(f"Same element query: Expected {expected}, got {actual}")
    print(f"Query (5,5): {'yes' if actual else 'no'} - PASS")
    
    # Test 2: Chain union then query
    dut.op_type.value = 0
    dut.a.value = 0
    dut.b.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    ref.union(0, 1)
    
    dut.op_type.value = 0
    dut.a.value = 1
    dut.b.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    ref.union(1, 2)
    
    # Query 0 and 2
    dut.op_type.value = 1
    dut.a.value = 0
    dut.b.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    expected = ref.query(0, 2)
    actual = int(dut.result.value)
    if actual != expected:
        raise TestFailure(f"Chain query: Expected {expected}, got {actual}")
    print(f"Query (0,2): {'yes' if actual else 'no'} - PASS")
    
    # Test 3: Disjoint sets
    dut.op_type.value = 1
    dut.a.value = 0
    dut.b.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    expected = ref.query(0, 3)
    actual = int(dut.result.value)
    if actual != expected:
        raise TestFailure(f"Disjoint query: Expected {expected}, got {actual}")
    print(f"Query (0,3): {'yes' if actual else 'no'} - PASS")
    
    print("
Edge case tests passed!")