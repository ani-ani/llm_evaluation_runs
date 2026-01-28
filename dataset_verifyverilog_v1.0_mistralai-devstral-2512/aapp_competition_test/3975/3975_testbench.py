import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def wait_for_signal(dut, signal_name, timeout_cycles=200):
    for _ in range(timeout_cycles):
        if is_value_defined(getattr(dut, signal_name).value) and int(getattr(dut, signal_name).value) == 1:
            return True
        yield RisingEdge(dut.clk)
    raise TestFailure(f"Timeout waiting for {signal_name}")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def config_circuit(dut, nodes):
    """
    nodes: list of tuples (type_str, src_a, src_b)
    types: 'AND', 'OR', 'XOR', 'NOT', 'IN'
    We map indices: Inputs 0-7 are nodes 8-15? Or we separate them.
    Let's map:
    Indices 0-7: Internal gates (0 is root usually)
    Indices 8-15: Inputs (8=IN0, 9=IN1...)
    """
    # Encode types to 2-bit
    type_map = {'AND': 0, 'OR': 1, 'XOR': 2, 'NOT': 3, 'IN': 3} # IN is treated as NOT with no input? No, special flag.
    
    for i, node in enumerate(nodes):
        typ, a, b = node
        
        # Config addr 0-15: src_a[3:0], src_b[3:0]
        dut.config_addr.value = i
        # Ensure inputs are mapped correctly
        # If input is IN0 (index 0 in problem), we map to 8 in our system
        val_a = a + 8 if 0 <= a <= 7 else a
        val_b = b + 8 if 0 <= b <= 7 else b
        
        dut.config_data.value = (val_a << 4) | val_b
        dut.config_en.value = 1
        await RisingEdge(dut.clk)
        
        # Config addr 16-31: type, is_input
        dut.config_addr.value = i + 16
        t_val = type_map[typ]
        is_in = 1 if typ == 'IN' else 0
        dut.config_data.value = (t_val << 1) | is_in
        await RisingEdge(dut.clk)
        
    dut.config_en.value = 0
    await RisingEdge(dut.clk)

class CircuitNode:
    def __init__(self, t, a, b):
        self.t = t
        self.a = a
        self.b = b

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_logical_circuit(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test Case 1: Example from prompt
    # Nodes: 0=AND(9,4), 1=IN, 2=IN, 3=XOR(6,5), 4=AND(3,7), 5=IN, 6=NOT(10), 7=IN, 8=IN, 9=AND(2,8)
    # Indices in prompt are 1-based. Inputs are 1,2,5,7,8,9 (corresponding to indices 1,2,5,7,8,9 in problem)
    # We need to map 1-based to our 0-based internal (0-7) and inputs (8-15)
    # Problem inputs: 2,3,6,8,9 (indices 2,3,6,8,9 in 1-based -> 1,2,5,7,8 in 0-based internal?
    # No, inputs are LEAVES. The example says Input 2, 3, 6, 8, 9.
    # In the description: Vertex 2 is IN 1. Vertex 3 is IN 1. Vertex 6 is IN 0. etc.
    # So vertices 1, 4, 5, 10 are gates.
    # Let's list nodes 0-9 (0-based):
    # 0: AND 9 4 (Vertex 1)
    # 1: IN 1    (Vertex 2) -> Input 1
    # 2: IN 1    (Vertex 3) -> Input 2
    # 3: XOR 6 5 (Vertex 4)
    # 4: AND 3 7 (Vertex 5)
    # 5: IN 0    (Vertex 6) -> Input 5
    # 6: NOT 10  (Vertex 7)
    # 7: IN 1    (Vertex 8) -> Input 7
    # 8: IN 1    (Vertex 9) -> Input 8
    # 9: AND 2 8 (Vertex 10)
    # Wait, input indices in description: "For each input, determine..."
    # The inputs are vertices that have type IN.
    # In the example output "10110", the order is ascending index of inputs.
    # Inputs are at indices 2, 3, 6, 8, 9 (1-based) -> 1, 2, 5, 7, 8 (0-based).
    # Output 10110 corresponds to these inputs.
    
    # Our mapping: Internal gates 0-7. Inputs 8-15.
    # We will construct the graph manually for the test.
    # Nodes 0-9 (0-based) in problem.
    # Map gates 0, 3, 4, 6, 9 to indices 0-4.
    # Map inputs 1, 2, 5, 7, 8 to indices 8-12.
    
    # Let's hardcode the nodes list for the testbench
    # Format: (type, src_a, src_b)
    # Indices in list correspond to our internal indices 0-4 (gates) and 8-12 (inputs).
    # src indices refer to these indices.
    
    # Node 0 (AND 9 4) -> idx 0. src_a=9, src_b=4.
    # Node 4 (AND 3 7) -> idx 1. src_a=3, src_b=7.
    # Node 3 (XOR 6 5) -> idx 2. src_a=6, src_b=5.
    # Node 6 (NOT 10) -> idx 3. src_a=10.
    # Node 9 (AND 2 8) -> idx 4. src_a=2, src_b=8.
    
    # Inputs:
    # Node 1 (IN) -> idx 8. No src.
    # Node 2 (IN) -> idx 9.
    # Node 5 (IN) -> idx 10.
    # Node 7 (IN) -> idx 11.
    # Node 8 (IN) -> idx 12.
    # Node 10 (IN) -> idx 13.
    
    # Mapping:
    # 0 -> 0 (Gate)
    # 1 -> 8 (Input)
    # 2 -> 9 (Input)
    # 3 -> 1 (Gate)
    # 4 -> 2 (Gate)
    # 5 -> 10 (Input)
    # 6 -> 3 (Gate)
    # 7 -> 11 (Input)
    # 8 -> 12 (Input)
    # 9 -> 4 (Gate)
    # 10-> 13 (Input)
    
    nodes = [
        ("AND", 9, 4),  # 0 (Gate) -> 0. src 9->12, 4->2
        ("IN", 0, 0),   # 1 (Input) -> 8
        ("IN", 0, 0),   # 2 (Input) -> 9
        ("XOR", 6, 5),  # 3 (Gate) -> 1. src 6->3, 5->10
        ("AND", 3, 7),  # 4 (Gate) -> 2. src 3->1, 7->11
        ("IN", 0, 0),   # 5 (Input) -> 10
        ("NOT", 10, 0), # 6 (Gate) -> 3. src 10->13
        ("IN", 0, 0),   # 7 (Input) -> 11
        ("IN", 0, 0),   # 8 (Input) -> 12
        ("AND", 2, 8),  # 9 (Gate) -> 4. src 2->9, 8->12
        ("IN", 0, 0),   # 10 (Input) -> 13
    ]
    
    # We need to pass the correct connections to config_circuit
    # Since config_circuit takes list of nodes for indices 0-15, we populate it.
    # Index 0: AND (src 12, 2)
    # Index 1: XOR (src 3, 10)
    # Index 2: AND (src 1, 11)
    # Index 3: NOT (src 13, 0)
    # Index 4: AND (src 9, 12)
    # Index 8: IN
    # Index 9: IN
    # Index 10: IN
    # Index 11: IN
    # Index 12: IN
    # Index 13: IN
    
    config_nodes = [None] * 16
    config_nodes[0] = ("AND", 12, 2)
    config_nodes[1] = ("XOR", 3, 10)
    config_nodes[2] = ("AND", 1, 11)
    config_nodes[3] = ("NOT", 13, 0)
    config_nodes[4] = ("AND", 9, 12)
    config_nodes[8] = ("IN", 0, 0)
    config_nodes[9] = ("IN", 0, 0)
    config_nodes[10] = ("IN", 0, 0)
    config_nodes[11] = ("IN", 0, 0)
    config_nodes[12] = ("IN", 0, 0)
    config_nodes[13] = ("IN", 0, 0)
    
    # Fill others with dummy gates to avoid X
    for i in range(16):
        if config_nodes[i] is None:
            config_nodes[i] = ("AND", 0, 0) # Dummy
            
    await config_circuit(dut, config_nodes)
    
    # Test inputs
    # Base values: Input 2=1, 3=1, 6=0, 8=1, 9=1 (1-based)
    # Input indices: 1, 2, 5, 7, 8 (0-based)
    # Base bits: 1, 1, 0, 1, 1
    # Let's set inputs 8-12 (corresponding to 1,2,5,7,8)
    # 8->1, 9->1, 10->0, 11->1, 12->1, 13->1 (Node 10 is input 9->1)
    
    base_input_vals = [0]*16
    base_input_vals[8] = 1
    base_input_vals[9] = 1
    base_input_vals[10] = 0
    base_input_vals[11] = 1
    base_input_vals[12] = 1
    base_input_vals[13] = 1
    
    # Pack inputs into 8-bit vector (since we only have 8 inputs in spec, but here we have 6)
    # We'll just use a wider vector or just map to the first 8 bits if we stick to spec.
    # Let's stick to the spec: 8 inputs max. Map the 6 inputs to bits 0-5.
    # But the spec expects `input_values[7:0]`. 
    # Let's assume `input_values` connects to IN nodes.
    # We will modify the testbench to accept `input_values` as a vector.
    # Bit 0 -> IN 0 -> Node 8
    # Bit 1 -> IN 1 -> Node 9
    # Bit 2 -> IN 2 -> Node 10
    # Bit 3 -> IN 3 -> Node 11
    # Bit 4 -> IN 4 -> Node 12
    # Bit 5 -> IN 5 -> Node 13
    
    dut.input_values.value = 0b011011 # Bits 0-5: 1,1,0,1,1,1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    found = False
    for _ in range(100):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            found = True
            break
        await RisingEdge(dut.clk)
    
    if not found:
        raise TestFailure("Timeout waiting for done")
        
    # Check results
    # Expected output (root 0): 1 (from example)
    # Expected sensitivities (for inputs 2,3,6,8,9 -> 1-based) = 1,0,1,1,0
    # Inputs correspond to indices 1,2,5,7,8 in problem -> Node 1,2,5,7,8 -> 0-based indices 1,2,5,7,8
    # Mapped to our 8-12.
    # Sensitivities should be for inputs 0-5 (bits 0-5).
    # Sens[0] (Node 8) -> Input 9 -> Sens 0
    # Sens[1] (Node 9) -> Input 2 -> Sens 1
    # Sens[2] (Node 10) -> Input 6 -> Sens 1
    # Sens[3] (Node 11) -> Input 8 -> Sens 1
    # Sens[4] (Node 12) -> (Node 10 is input 9? No. Wait.)
    
    # Let's trace strictly.
    # Node 0 (Root): AND (12, 2).
    # Node 12 (Input 8): Value 1. Sens? Root is AND. Other input (Node 2) is AND(1,11).
    # Node 2: AND(1,11) -> 1 & 1 = 1. 
    # Node 0 = 1 & 1 = 1.
    # If Input 8 flips (Node 12): Root becomes 0 & 1 = 0. Changed. Sens 1.
    # If Input 2 flips (Node 9): Node 2 becomes 0 & 1 = 0. Root 1 & 0 = 0. Changed. Sens 1.
    # If Input 6 flips (Node 10): Node 3 (XOR 3,10) becomes 0^1=1. Node 1 (Root input A) becomes 1 (AND 12,2) is not connected to 3.
    # Node 0 inputs: 12, 2.
    # Node 2 inputs: 1, 11.
    # Node 1: XOR(3,10).
    # Node 3: NOT(13).
    # 
    # Full Trace:
    # Base:
    # 8:1, 9:1, 10:0, 11:1, 12:1, 13:1
    # 3: NOT(13) -> 0
    # 1: XOR(3,10) -> 0 ^ 0 = 0
    # 2: AND(1,11) -> 0 & 1 = 0
    # 4: AND(3,7) -> 0 & 1 = 0 (Note: Node 4 is index 2 in our config? No, index 2 is AND(1,11). Wait.)
    # Let's re-verify config_nodes array:
    # 0: AND(12, 2)
    # 1: XOR(3, 10)
    # 2: AND(1, 11)
    # 3: NOT(13, 0)
    # 4: AND(9, 12)
    # 
    # Wait, where is Vertex 4 (AND 3 7) from the problem?
    # Vertex 4 is Vertex 5 (1-based) -> Index 4 (0-based).
    # Vertex 4 connects 3 and 7.
    # Vertex 3 is XOR(6,5). Vertex 5 is IN 0.
    # Vertex 6 is NOT(10).
    # Vertex 7 is IN 1.
    # Vertex 8 is IN 1.
    # Vertex 9 is AND(2,8).
    # Vertex 10 is IN 1.
    # 
    # Mapping:
    # 0 (Vertex 1): AND(9,4) -> Target 0: AND(9, 4).
    # 1 (Vertex 2): IN -> Target 8.
    # 2 (Vertex 3): IN -> Target 9.
    # 3 (Vertex 4): XOR(6,5) -> Target 1: XOR(6, 5).
    # 4 (Vertex 5): AND(3,7) -> Target 2: AND(3, 7).
    # 5 (Vertex 6): IN -> Target 10.
    # 6 (Vertex 7): NOT(10) -> Target 3: NOT(10).
    # 7 (Vertex 8): IN -> Target 11.
    # 8 (Vertex 9): IN -> Target 12.
    # 9 (Vertex 10): AND(2,8) -> Target 4: AND(2, 8).
    # 10 (Vertex 11): IN -> Target 13. (Wait, example says 10 vertices. Vertex 10 is AND 2 8. Ah. Vertex 10 is AND 2 8. There is no Vertex 11. So 10 vertices.)
    # Example Input:
    # 10
    # AND 9 4
    # IN 1
    # IN 1
    # XOR 6 5
    # AND 3 7
    # IN 0
    # NOT 10
    # IN 1
    # IN 1
    # AND 2 8
    # 
    # Vertices: 1 to 10.
    # 1: AND (9, 4)
    # 2: IN
    # 3: IN
    # 4: XOR (6, 5)
    # 5: AND (3, 7)
    # 6: IN
    # 7: NOT (10)
    # 8: IN
    # 9: IN
    # 10: AND (2, 8)
    # 
    # Inputs are: 2, 3, 6, 8, 9.
    # 
    # My remapping:
    # Gates: 1, 4, 5, 7, 10 -> 0, 1, 2, 3, 4
    # Inputs: 2, 3, 6, 8, 9 -> 8, 9, 10, 11, 12
    # 
    # Config:
    # 0: AND(9, 4) -> src: 12 (9), 1 (4) -> Wait, 4 is a GATE (index 2 in my list).
    # 1: XOR(6, 5) -> src: 3 (6), 2 (5) -> 6 is GATE (index 3), 5 is INPUT (index 10).
    # 2: AND(3, 7) -> src: 1 (3), 4 (7) -> 3 is INPUT (index 9), 7 is INPUT (index 11).
    # 3: NOT(10) -> src: 5 (10) -> 10 is INPUT (index 13)? No, 10 is GATE (index 4).
    # 4: AND(2, 8) -> src: 9 (2), 11 (8) -> 2 is INPUT (index 8), 8 is INPUT (index 12).
    # 
    # Let's redo the mapping carefully:
    # Indices 0-4: Gates (1, 4, 5, 7, 10)
    # Indices 8-12: Inputs (2, 3, 6, 8, 9)
    # Indices 13: Unused
    # 
    # 1 -> 0
    # 2 -> 8
    # 3 -> 9
    # 4 -> 1
    # 5 -> 2
    # 6 -> 10
    # 7 -> 3
    # 8 -> 11
    # 9 -> 12
    # 10 -> 4
    # 
    # Connections:
    # 1 (0): AND(9, 4) -> (12, 1)
    # 4 (1): XOR(6, 5) -> (10, 2)
    # 5 (2): AND(3, 7) -> (9, 3)
    # 7 (3): NOT(10) -> (4)
    # 10 (4): AND(2, 8) -> (8, 11)
    # 
    # Let's verify the logic with these indices:
    # Inputs (0-based in problem -> 1-based in prompt): 
    # 2 -> 1 (My 8)
    # 3 -> 2 (My 9)
    # 6 -> 5 (My 10)
    # 8 -> 7 (My 11)
    # 9 -> 8 (My 12)
    # 
    # Base values:
    # 1 -> 1 (Input)
    # 2 -> 1 (Input)
    # 5 -> 0 (Input)
    # 7 -> 1 (Input)
    # 8 -> 1 (Input)
    # 
    # Evaluation:
    # 0 (1): AND(12, 1). 12 is Input 9 -> 1. 1 is Node 4 (XOR).
    # 1 (4): XOR(10, 2). 10 is Input 6 -> 0. 2 is Node 5 (AND).
    # 2 (5): AND(9, 3). 9 is Input 3 -> 1. 3 is Node 7 (NOT).
    # 3 (7): NOT(4). 4 is Node 10 (AND).
    # 4 (10): AND(8, 11). 8 is Input 2 -> 1. 11 is Input 8 -> 1.
    # 
    # Compute bottom up:
    # 4: AND(1,1) = 1
    # 3: NOT(1) = 0
    # 2: AND(1,0) = 0
    # 1: XOR(0,0) = 0
    # 0: AND(1,0) = 0. 
    # Wait, example output is "10110". If I change Input 2 (Vertex 2, My 8), Output should be 1.
    # If My 8 flips to 0: Node 4 becomes 0 & 1 = 0. Node 3 becomes NOT(0) = 1. Node 2 becomes AND(1,1) = 1. Node 1 becomes XOR(1,0) = 1. Node 0 becomes AND(1,1) = 1.
    # Original Output 0. New Output 1. Change is 1. Correct.
    # Sensitivity for Input 2 (My 8) is 1.
    # 
    # Check Input 3 (My 9):
    # If My 9 flips to 0: Node 2 becomes AND(0,0) = 0. Node 1 becomes XOR(0,0) = 0. Node 0 becomes AND(1,0) = 0.
    # No change. Sensitivity 0.
    # Matches example "0" for second char.
    # 
    # So the mapping is correct.
    
    # Re-configure with correct nodes
    config_nodes = [None] * 16
    config_nodes[0] = ("AND", 12, 1)  # 1->4->1
    config_nodes[1] = ("XOR", 10, 2)  # 4->6->10, 4->5->2
    config_nodes[2] = ("AND", 9, 3)   # 5->3->9, 5->7->3
    config_nodes[3] = ("NOT", 4, 0)   # 7->10->4
    config_nodes[4] = ("AND", 8, 11)  # 10->2->8, 10->8->11
    config_nodes[8] = ("IN", 0, 0)
    config_nodes[9] = ("IN", 0, 0)
    config_nodes[10] = ("IN", 0, 0)
    config_nodes[11] = ("IN", 0, 0)
    config_nodes[12] = ("IN", 0, 0)
    # 13 unused
    
    for i in range(16):
        if config_nodes[i] is None:
            config_nodes[i] = ("AND", 0, 0)
            
    await config_circuit(dut, config_nodes)
    
    # Inputs: 2, 3, 6, 8, 9 are 1, 1, 0, 1, 1
    # My indices: 8, 9, 10, 11, 12
    # Bits 0-4: 8->0, 9->1, 10->2, 11->3, 12->4
    # Values: 1, 1, 0, 1, 1 -> Binary 1 1 1 0 1 = 0b11101 = 29
    dut.input_values.value = 29
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    found = False
    for _ in range(100):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            found = True
            break
        await RisingEdge(dut.clk)
    
    if not found:
        raise TestFailure("Timeout")
        
    # Check outputs
    # Result: 0 (Base output)
    # Sensitivities: 
    # Input 8 (Bit 0): 1
    # Input 9 (Bit 1): 0
    # Input 10 (Bit 2): 1
    # Input 11 (Bit 3): 1
    # Input 12 (Bit 4): 0
    # Expected string: 10110
    # Result bit: 0
    # Sensitivity vector should be 0b00111 (Little endian? 8->0, 9->1...)
    # If we read `sensitivity` as integer:
    # Bit 0 (Node 8) = 1
    # Bit 1 (Node 9) = 0
    # Bit 2 (Node 10) = 1
    # Bit 3 (Node 11) = 1
    # Bit 4 (Node 12) = 0
    # Value = 1 + 4 + 8 = 13.
    
    res = int(dut.result.value)
    sens = int(dut.sensitivity.value)
    
    if res != 0:
        raise TestFailure(f"Expected result 0, got {res}")
        
    expected_sens = 0
    expected_sens |= (1 << 0) # Node 8
    expected_sens |= (1 << 2) # Node 10
    expected_sens |= (1 << 3) # Node 11
    
    if sens != expected_sens:
        raise TestFailure(f"Expected sensitivity {expected_sens} (binary {bin(expected_sens)}), got {sens} (binary {bin(sens)})")
        
    cocotb.log.info(f"Success! Result={res}, Sensitivity={bin(sens)}")
