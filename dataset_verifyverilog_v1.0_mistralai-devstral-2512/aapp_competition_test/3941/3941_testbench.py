import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    v = int(v)
    if v < 0:
        return 0
    if v > max_val:
        return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'load_room'):
        dut.load_room.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test Logic
class DoorSwitchSim:
    def __init__(self, n, m, door_status):
        self.n = n
        self.m = m
        self.door_status = door_status
        self.switches = [[] for _ in range(n)]  # switches controlling each room
        # Adjacency matrix for switches
        self.adj = [[-1] * m for _ in range(m)]
        self.solution_found = True

    def add_room_constraints(self, room_idx, switch_list):
        if len(switch_list) != 2:
            # In this problem every door is controlled by exactly 2 switches
            self.solution_found = False
            return
        s1, s2 = switch_list
        # Edge weight is derived from door status. 
        # If door is unlocked (1), switches must be same state.
        # If door is locked (0), switches must be opposite state.
        # In the BFS check: if edge == 1, color[v] == color[u]
        # if edge == 0, color[v] != color[u]
        # Python solution converts: edge = 1 - door_status
        weight = 1 - self.door_status[room_idx]
        
        # Store in matrix
        self.adj[s1][s2] = weight
        self.adj[s2][s1] = weight

    def solve(self):
        if not self.solution_found:
            return False
        
        m = self.m
        color = [-1] * m
        
        for start_node in range(m):
            if color[start_node] == -1:
                color[start_node] = 0
                queue = [start_node]
                head = 0
                while head < len(queue):
                    u = queue[head]
                    head += 1
                    for v in range(m):
                        if self.adj[u][v] != -1:
                            weight = self.adj[u][v]
                            if color[v] == -1:
                                if weight == 1:
                                    color[v] = color[u]
                                else:
                                    color[v] = 1 - color[u]
                                queue.append(v)
                            else:
                                if weight == 1 and color[v] != color[u]:
                                    return False
                                if weight == 0 and color[v] == color[u]:
                                    return False
        return True

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_door_unlocker(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Define test cases based on provided data
    # Scaled down to fit 16x16 constraint if needed, but checking logic
    test_cases = [
        # Case 1: Input from examples (scaled logic check)
        # n=3, m=3
        # r = [1, 0, 1]
        # Switches: 
        # S1: [1, 3]
        # S2: [1, 2]
        # S3: [2, 3]
        {
            "n": 3, "m": 3,
            "door_status": [1, 0, 1],
            "rooms": [
                ([0, 1, 2], [1, 0, 0]),  # Room 0 (1-based 1) controlled by S0, S1 (weights from r[0]=1 -> weight 0)
                ([0, 1, 2], [0, 1, 0]),  # Room 1 (1-based 2) controlled by S1, S2 (weights from r[1]=0 -> weight 1)
                ([0, 1, 2], [1, 0, 1])   # Room 2 (1-based 3) controlled by S0, S2 (weights from r[2]=1 -> weight 0)
            ],
            "expected": 0 # NO
        },
        # Case 2: Input 2
        # r = [1, 0, 1]
        # S1: [1, 2, 3]
        # S2: [2]
        # S3: [1, 3]
        # Note: Problem statement says each door controlled by exactly 2 switches.
        # The provided example data might have doors controlled by more or fewer in raw input, 
        # but we must filter to valid pairs or handle constraints. 
        # However, for hardware benchmarking, we stick to the "exactly two" constraint.
        # We will generate a simplified valid case.
        {
            "n": 3, "m": 3,
            "door_status": [1, 0, 1],
            "rooms": [
                ([0, 2], [0, 0]), # Room 1 (r=1) S0, S2 -> weight 0
                ([0, 1], [1, 1]), # Room 2 (r=0) S0, S1 -> weight 1
                ([1, 2], [0, 0])  # Room 3 (r=1) S1, S2 -> weight 0
            ],
            "expected": 1 # YES
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        n = tc["n"]
        m = tc["m"]
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Load rooms
        for room_idx in range(n):
            # Determine which switches control this room
            # In our test structure, 'rooms' list contains (switch_indices, weights)
            # We need to reconstruct the switch_ctrl vector for the hardware
            # Hardware takes switch_ctrl packed 256 bits.
            # We also need to pass the 'weight' derived from door status.
            
            # Extract data for this room from test case
            # We have a list of switches and their corresponding weight for this room
            # In hardware, the weight is implicit from `door_status` input, 
            # but our hardware processes one room at a time. 
            # We need to feed it: room_index, and the switch connections.
            
            sw_list = tc["rooms"][room_idx][0]
            weight_list = tc["rooms"][room_idx][1]
            
            # The hardware expects `switch_ctrl` packed.
            # However, the problem says each door is controlled by EXACTLY 2 switches.
            # So `switch_ctrl` will have exactly 2 bits set.
            # We also need to set the `door_status` input. 
            # Since hardware might compute weight internally or take it, let's assume
            # we pass the `door_status` bit for this room.
            
            # Let's look at the prompt's interface: 
            # `door_status [15:0]` (vector of room statuses)
            # `switch_ctrl [255:0]` (packed)
            # `room_index [3:0]`
            
            # To make it simple for the driver:
            # We set `room_index`.
            dut.room_index.value = room_idx
            
            # Build `switch_ctrl` vector
            packed_ctrl = 0
            # We only care about the 2 active switches for this room
            # The hardware will update the adj matrix for these pairs.
            # BUT, to know the weight, the hardware needs the door status for this room.
            # We will drive `door_status` as a 16-bit vector where bit `room_idx` is the status.
            
            # Construct packed switch control
            # In a real scenario, `switch_ctrl` might indicate which switches are connected to the CURRENT room.
            # Since each door has 2 switches, we set bits in `switch_ctrl`.
            packed_ctrl = 0
            for sw in sw_list:
                packed_ctrl |= (1 << sw)
            
            # We need to drive the `door_status` vector.
            # Let's assume `door_status` is a 16-bit input bus.
            status_vec = 0
            for r_idx, stat in enumerate(tc["door_status"]):
                if stat:
                    status_vec |= (1 << r_idx)
            
            dut.door_status.value = status_vec
            dut.switch_ctrl.value = packed_ctrl
            
            # Pulse load_room
            dut.load_room.value = 1
            await RisingEdge(dut.clk)
            dut.load_room.value = 0
            await RisingEdge(dut.clk) # Small gap
        
        # Wait for done
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        expected = tc["expected"]
        
        if result != expected:
            raise TestFailure(f"Test {i+1} Failed: Expected {expected}, Got {result}")
        
        # Reset for next test
        await reset_dut(dut)

    cocotb.log.info("All tests passed")
