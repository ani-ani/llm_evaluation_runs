import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_balloon_eq(dut):
    """Test the balloon_eq module with provided test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.program_id.value = 0
    dut.node_type.value = 0
    dut.node_value.value = 0
    dut.child1_idx.value = 255
    dut.child2_idx.value = 255
    dut.num_nodes.value = 0
    dut.node_valid.value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to load program
    async def load_program(prog_id, nodes):
        dut.program_id.value = prog_id
        dut.num_nodes.value = len(nodes)
        for node in nodes:
            dut.node_type.value = node['type']
            dut.node_value.value = node.get('value', 0)
            dut.child1_idx.value = node.get('c1', 255)
            dut.child2_idx.value = node.get('c2', 255)
            dut.node_valid.value = 1
            await RisingEdge(dut.clk)
        dut.node_valid.value = 0

    # Helper to run test
    async def run_test(prog_a, prog_b, expected):
        # Load A
        await load_program(0, prog_a)
        # Load B
        await load_program(1, prog_b)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 50:
            raise TestFailure("Timeout waiting for done")
            
        # Check result
        # 1=Equal, 2=Not Equal
        actual = int(dut.result.value)
        
        # Map expected string to result code
        exp_code = 1 if expected == "equal" else 2
        
        if actual != exp_code:
            raise TestFailure(f"Expected {expected} (code {exp_code}), got {actual}")
        
        await RisingEdge(dut.clk)

    # Test Case 1
    # concat(shuffle([1,2]),shuffle([1,2]))
    # Nodes: [1,2] (leaf), shuffle(leaf), [1,2] (leaf), shuffle(leaf), concat(shuffle, shuffle)
    # Node 0: VALUE 1 (child1 of 2)
    # Node 1: VALUE 2 (child2 of 2)
    # Node 2: SHUFFLE (c1=0, c2=1)
    # Node 3: VALUE 1 (child1 of 4)
    # Node 4: VALUE 2 (child2 of 4)
    # Node 5: SHUFFLE (c1=3, c2=4)
    # Node 6: CONCAT (c1=2, c2=5)
    # Total 7 nodes
    prog1_a = [
        {'type': 0, 'value': 1}, # 0
        {'type': 0, 'value': 2}, # 1
        {'type': 2, 'c1': 0, 'c2': 1}, # 2
        {'type': 0, 'value': 1}, # 3
        {'type': 0, 'value': 2}, # 4
        {'type': 2, 'c1': 3, 'c2': 4}, # 5
        {'type': 1, 'c1': 2, 'c2': 5}, # 6
    ]
    
    # shuffle([1,2,1,2])
    # Nodes: [1,2,1,2] (leaf)
    # Node 0: VALUE 1 (child1 of 4)
    # Node 1: VALUE 2 (child2 of 4)
    # Node 2: VALUE 1 (child3 of 4? No, binary tree, need to flatten)
    # Actually, input is [1,2,1,2].
    # Let's represent [1,2,1,2] as VALUE 1 + VALUE 2 + VALUE 1 + VALUE 2 ?
    # The parser needs to handle lists. In hardware, [1,2,1,2] is just a VALUE node with multiset {1,2,1,2}.
    # But we need to represent it as a tree.
    # [1,2,1,2] is a list constructor with 4 elements.
    # Our module takes binary tree nodes.
    # We can represent [1,2,1,2] as concat(concat(concat([1],[2]),[1]),[2]).
    # Node 0: VALUE 1
    # Node 1: VALUE 2
    # Node 2: VALUE 1
    # Node 3: VALUE 2
    # Node 4: CONCAT (0, 1)
    # Node 5: CONCAT (4, 2)
    # Node 6: CONCAT (5, 3)
    # Node 7: SHUFFLE (6)
    prog1_b = [
        {'type': 0, 'value': 1}, # 0
        {'type': 0, 'value': 2}, # 1
        {'type': 0, 'value': 1}, # 2
        {'type': 0, 'value': 2}, # 3
        {'type': 1, 'c1': 0, 'c2': 1}, # 4
        {'type': 1, 'c1': 4, 'c2': 2}, # 5
        {'type': 1, 'c1': 5, 'c2': 3}, # 6
        {'type': 2, 'c1': 6, 'c2': 255}, # 7
    ]
    await run_test(prog1_a, prog1_b, "not equal")

    # Test Case 2
    # sorted(concat([3,2,1],[4,5,6]))
    # [1,2,3,4,5,6]
    # We need to represent sorted list as sorted list in canonical form.
    # A is: [3,2,1] + [4,5,6] -> [3,2,1,4,5,6] -> sorted -> {1,2,3,4,5,6}
    # B is: [1,2,3,4,5,6] -> {1,2,3,4,5,6}
    # Since we compare multisets, both are {1,2,3,4,5,6}.
    
    # A: [3,2,1] concat [4,5,6] sorted
    # Tree for [3,2,1]: Node 0:3, Node 1:2, Node 2:1, Node 3:Concat(0,1), Node 4:Concat(3,2)
    # Tree for [4,5,6]: Node 5:4, Node 6:5, Node 7:6, Node 8:Concat(5,6), Node 9:Concat(8,7)
    # Node 10: Concat(4,9)
    # Node 11: Sorted(10)
    prog2_a = [
        {'type':0, 'value':3}, {'type':0, 'value':2}, {'type':0, 'value':1},
        {'type':1, 'c1':0, 'c2':1}, {'type':1, 'c1':3, 'c2':2},
        {'type':0, 'value':4}, {'type':0, 'value':5}, {'type':0, 'value':6},
        {'type':1, 'c1':5, 'c2':6}, {'type':1, 'c1':8, 'c2':7},
        {'type':1, 'c1':4, 'c2':9}, {'type':3, 'c1':10, 'c2':255}
    ]
    # B: [1,2,3,4,5,6]
    # Node 0..5: Values
    # Node 6..10: Concats to form list
    prog2_b = [
        {'type':0, 'value':1}, {'type':0, 'value':2}, {'type':0, 'value':3},
        {'type':0, 'value':4}, {'type':0, 'value':5}, {'type':0, 'value':6},
        {'type':1, 'c1':0, 'c2':1}, {'type':1, 'c1':6, 'c2':2},
        {'type':1, 'c1':7, 'c2':3}, {'type':1, 'c1':8, 'c2':4},
        {'type':1, 'c1':9, 'c2':5}
    ]
    await run_test(prog2_a, prog2_b, "equal")

    # Test Case 3
    # concat(sorted([4,3,2,1]),shuffle([1]))
    # sorted([4,3,2,1]) -> {1,2,3,4}
    # shuffle([1]) -> {1}
    # concat -> {1,1,2,3,4}
    
    # concat(concat([3,2,1],shuffle([4])),sorted([1]))
    # [3,2,1] -> {1,2,3}
    # shuffle([4]) -> {4}
    # concat -> {1,2,3,4}
    # sorted([1]) -> {1}
    # concat -> {1,1,2,3,4}
    # These are equal.
    
    # A: sorted([4,3,2,1]) concat shuffle([1])
    # sorted([4,3,2,1]): V4,V3,V2,V1 -> concat -> concat -> concat -> sorted -> {1,2,3,4}
    # shuffle([1]): V1 -> shuffle -> {1}
    # concat -> {1,1,2,3,4}
    # Note: concat distributes over multisets (union).
    
    # Let's build A nodes:
    # [4,3,2,1] sorted:
    # 0:4, 1:3, 2:2, 3:1
    # 4: C(0,1), 5: C(4,2), 6: C(5,3) -> [4,3,2,1]
    # 7: S(6) -> {1,2,3,4}
    # shuffle([1]):
    # 8: 1
    # 9: SH(8) -> {1}
    # 10: C(7,9) -> {1,1,2,3,4}
    prog3_a = [
        {'type':0,'value':4}, {'type':0,'value':3}, {'type':0,'value':2}, {'type':0,'value':1},
        {'type':1,'c1':0,'c2':1}, {'type':1,'c1':4,'c2':2}, {'type':1,'c1':5,'c2':3},
        {'type':3,'c1':6,'c2':255},
        {'type':0,'value':1},
        {'type':2,'c1':8,'c2':255},
        {'type':1,'c1':7,'c2':9}
    ]
    
    # B: concat(concat([3,2,1],shuffle([4])),sorted([1]))
    # [3,2,1]:
    # 0:3, 1:2, 2:1
    # 3: C(0,1), 4: C(3,2)
    # shuffle([4]):
    # 5:4
    # 6: SH(5)
    # concat(4,6) -> {1,2,3,4}
    # 7: C(4,6)
    # sorted([1]):
    # 8:1
    # 9: S(8)
    # concat(7,9) -> {1,1,2,3,4}
    prog3_b = [
        {'type':0,'value':3}, {'type':0,'value':2}, {'type':0,'value':1},
        {'type':1,'c1':0,'c2':1}, {'type':1,'c1':3,'c2':2},
        {'type':0,'value':4},
        {'type':2,'c1':5,'c2':255},
        {'type':1,'c1':4,'c2':6},
        {'type':0,'value':1},
        {'type':3,'c1':8,'c2':255},
        {'type':1,'c1':7,'c2':9}
    ]
    await run_test(prog3_a, prog3_b, "equal")

    # Additional test: Not equal
    # [1,2] vs [1,3]
    prog4_a = [{'type':0,'value':1}, {'type':0,'value':2}] # Just values, need to be connected to a root? 
    # The module expects a full tree. Let's make a root CONCAT for [1,2]
    # 0:1, 1:2, 2:Concat(0,1)
    prog4_a = [{'type':0,'value':1}, {'type':0,'value':2}, {'type':1,'c1':0,'c2':1}]
    # [1,3]
    prog4_b = [{'type':0,'value':1}, {'type':0,'value':3}, {'type':1,'c1':0,'c2':1}]
    await run_test(prog4_a, prog4_b, "not equal")

    print("All tests passed!")
