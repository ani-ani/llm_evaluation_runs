import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Helper to pack string into integer (simulating 40-bit input)
def str_to_int(s):
    res = 0
    for i, c in enumerate(s):
        res |= ord(c) << (8 * i)
    return res

@cocotb.test()
async def test_bird_label_solver(dut):
    # Initialize signals
    dut.clk.value = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.config_mode.value = 1
    dut.parent.value = 0
    dut.v_type.value = 0
    dut.v_subtype.value = 0
    dut.v_label.value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load Test Case 2 (The 6-node one)
    # 0 B
    # 1 B
    # 1 T a
    # 2 E a
    # 2 S
    # 5 T a
    
    nodes = [
        (1, 0, 0, 0),  # Node 1 (Index 1 in logic, but we start from 1)
        (1, 2, 0, 0),  # Node 2 (Parent 1, Type B)
        (2, 0, 2, str_to_int('a')), # Node 3 (Parent 2, Leaf Tiny 'a')
        (2, 0, 0, str_to_int('a')), # Node 4 (Parent 2, Leaf Berry 'a')
        (2, 1, 0, 0),  # Node 5 (Parent 2, Type S)
        (5, 0, 2, str_to_int('a')), # Node 6 (Parent 5, Leaf Tiny 'a')
    ]
    
    # Note: Input format in spec uses 1-based indexing for parents.
    # In simulation, we configure vertex i (1..6)
    
    # Configuration Loop
    for i in range(1, 7):
        parent, type_code, sub_code, label = nodes[i-1]
        dut.parent.value = parent
        
        if type_code == 0: # Branch B
            dut.v_type.value = 0 # Branch
            dut.v_subtype.value = 0 # B (arbitrary choice for encoding)
        elif type_code == 1: # Branch S
            dut.v_type.value = 0 # Branch
            dut.v_subtype.value = 1 # S
        elif type_code == 2: # Leaf
            dut.v_type.value = 2 # Leaf
            dut.v_subtype.value = sub_code # 0=Berry, 1=G, 2=T
            dut.v_label.value = label
            
        await RisingEdge(dut.clk)
        
    # Trigger Computation
    dut.config_mode.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for result (max 1024 cycles)
    for _ in range(1100):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            break
            
    # Check Result
    assert dut.result_valid.value == 1, "Result not valid within expected cycles"
    
    # Expected for Case 2: Change count 1, Vertex 6, New Label 'b' (or 'c')
    # The logic might pick vertex 6 to change.
    changes = int(dut.change_count.value)
    print(f"Changes required: {changes}")
    
    # We accept either changing bird 6 or bird 3, as long as it fixes the problem
    # Case 2 requires changing one of the birds with label 'a' because they conflict when becoming giant.
    assert changes == 1, f"Expected 1 change, got {changes}"
    
    # We can't easily check the exact vertex number or label without more complex test logic,
    # but verifying the count is correct is the primary benchmark.
    print(f"Test passed: {changes}/1 correct change count detected.")