import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to convert integer to 8-bit binary
def to_bin(val, bits=8):
    return val & ((1 << bits) - 1)

@cocotb.test()
async def test_scavenger_hunt_basic(dut):
    """Test basic functionality with a simple 3-task case"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.task_idx.value = 0
    dut.p_in.value = 0
    dut.t_in.value = 0
    dut.d_in.value = 0
    dut.dist_in.value = 0
    dut.dist_src.value = 0
    dut.dist_dst.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Configuration Phase
    # Task 0: p=93, t=82, d=444 (scaled: 93, 82, 255 (since >255)) -> Wait, input max is 1440, we need to scale.
    # The problem says T <= 1440. We need to scale inputs to fit 8-bit (255).
    # Scaling factor: 1440 / 255 ≈ 5.6. We will use a factor of 6 for simplicity or just ensure inputs are small.
    # Let's use the scaled values directly as per problem adaptation: inputs must fit 0-255.
    # Let's simulate the sample input: 
    # 3 352 -> n=3, T=352 (Scale T to 255? No, max T is 1440. Let's assume inputs are pre-scaled or we handle larger.
    # Wait, prompt says "Maximum total time T = 255". So we must scale sample.
    # Sample 1: T=352. Scaled / 2 = 176.
    # Task 1: 93, 82, 444 -> 93, 82, 255 (no deadline effectively)
    # Task 2: 92, 76, 436 -> 92, 76, 255
    # Task 3: 99, 62, -1 -> 99, 62, 255
    
    # Distances (sample first row: 0 70 66 71 97 -> 0, 70, 66, 71, 97. Scaled / 2 = 0, 35, 33, 35, 48)
    
    # Let's define the test data (scaled roughly by factor 2 to fit 8-bit)
    # Nodes: 0,1,2 (Tasks), 3 (Start), 4 (End) -> Indices in prompt are 0-5 (tasks), 6 (start), 7 (end)
    
    # Tasks (indices 0, 1, 2):
    # T0: p=46, t=41, d=255
    # T1: p=46, t=38, d=255
    # T2: p=49, t=31, d=255
    
    # Distances (0=Start, 1=End, others are tasks 0,1,2. Prompt uses 0-5 tasks, 6 start, 7 end)
    # Let's map: Start=6, End=7. Tasks=0,1,2.
    # We need to fill 8x8 matrix.
    
    # Example from sample (scaled by 1.5 to keep integers, max < 100):
    # T0: p=93, t=82, d=444 -> p=93, t=82, d=255 (capped)
    # T1: p=92, t=76, d=436 -> p=92, t=76, d=255
    # T2: p=99, t=62, d=-1 -> p=99, t=62, d=255
    # T=352 -> (let's set T=200 for test, as 352 > 255 limit imposed by prompt)
    # We will test with T=200.
    
    # Config Tasks
    tasks_config = [
        (93, 82, 255), # Task 0
        (92, 76, 255), # Task 1
        (99, 62, 255)  # Task 2
    ]
    
    for i, (p, t, d) in enumerate(tasks_config):
        dut.task_idx.value = i
        dut.p_in.value = p
        dut.t_in.value = t
        dut.d_in.value = d
        await RisingEdge(dut.clk)
    
    # Config Distances
    # Matrix from sample (rows 0-2, cols 0-2, plus start/end)
    # Sample: 
    # 0: 0 70 66 71 97 (cols: 0,1,2,Start,End) -> 0,1,2,3,4? Sample indices: 0,1,2 are tasks? No sample says n=3, then 3 rows of tasks, then n+2 rows of matrix.
    # Sample rows: 
    # 0: 0 70 66 71 97
    # 1: 76 0 87 66 74
    # 2: 62 90 0 60 94
    # 3: 60 68 68 0 69 (Start)
    # 4: 83 78 83 73 0 (End)
    
    # We have 8 locations. Let's fill sparse.
    # Indices: 0,1,2 (tasks), 6 (start), 7 (end).
    # We'll define distance pairs.
    
    # Dist[0][0]=0, [0][1]=70, [0][2]=66, [0][6]=71, [0][7]=97
    # Dist[1][0]=76, [1][1]=0, [1][2]=87, [1][6]=66, [1][7]=74
    # Dist[2][0]=62, [2][1]=90, [2][2]=0, [2][6]=60, [2][7]=94
    # Dist[6][0]=60, [6][1]=68, [6][2]=68, [6][6]=0, [6][7]=69
    # Dist[7][0]=83, [7][1]=78, [7][2]=83, [7][6]=73, [7][7]=0
    
    dist_matrix = [
        [0, 70, 66, 0, 0, 0, 71, 97],
        [76, 0, 87, 0, 0, 0, 66, 74],
        [62, 90, 0, 0, 0, 0, 60, 94],
        [0]*8,
        [0]*8,
        [0]*8,
        [60, 68, 68, 0, 0, 0, 0, 69],
        [83, 78, 83, 0, 0, 0, 73, 0]
    ]
    
    # Scale distances to fit 8-bit? Sample max is 97, which fits.
    
    for src in range(8):
        for dst in range(8):
            dut.dist_src.value = src
            dut.dist_dst.value = dst
            dut.dist_in.value = dist_matrix[src][dst]
            await RisingEdge(dut.clk)
    
    # Start Computation
    # Note: We need to set T=200 for this test because prompt limits T to 255.
    # We will modify the internal T limit or assume the module has a T input.
    # The prompt spec provided inputs but missed T input explicitly in the list! 
    # I will assume T is a static parameter or needs to be added.
    # Let's add T as an input for generality (8-bit).
    # But looking at the prompt's "Inputs" list, T is not there. 
    # However, the problem definition requires T. 
    # I will proceed assuming T is a separate input `input [7:0] time_limit` or similar, or I missed it.
    # Let's re-read prompt: "Inputs..." lists task config and dist. 
    # OK, I will assume the user forgot T. I will add `input [7:0] T_limit` to the module in my head, or handle it.
    # Actually, to make the testbench work, I must define the interface.
    # I will add `dut.T_limit.value = 200` and assume the Verilog module has it.
    
    # Wait, the prompt says "Maximum total time T = 255". Maybe it's a parameter?
    # To be safe, I will check if the generated testbench can handle this.
    # The user provided the Prompt. I must follow the Prompt.
    # The Prompt's Input list does NOT include T.
    # This is a flaw in the prompt definition. 
    # I will modify the module in my reasoning to include `input [7:0] T_limit` to make it solvable.
    # OR, I can set T as a localparam in Verilog. But the test needs to vary it.
    # I will add `T_limit` to the testbench dut interaction.
    
    # Let's assume `dut.T_limit` exists based on the problem logic requirement.
    if hasattr(dut, 'T_limit'):
        dut.T_limit.value = 200
    else:
        print("Warning: T_limit not found in dut, assuming fixed or parameterized")

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Timeout waiting for done"
    
    # Check results
    # Expected: Task 2 has 99 points. Can we do it?
    # Start -> Task 2 -> End
    # Time: Dist(6,2) + t(2) + Dist(2,7) = 60 + 62 + 94 = 216. > 200. Too slow.
    # Try Task 0: Dist(6,0)=71 + 82 + Dist(0,7)=97 = 250. > 200.
    # Try Task 1: Dist(6,1)=66 + 76 + Dist(1,7)=74 = 216. > 200.
    # None alone fit 200? 
    # Wait, let's check T=250.
    # If T=250, Task 0 fits (250). Points 93.
    # If T=250, Task 1 fits (216). Points 92.
    # If T=250, Task 2 fits (216). Points 99. 
    # So with T=250, max is 99 (Task 2).
    
    # Let's set T_limit to 250 for this test to get a meaningful result.
    if hasattr(dut, 'T_limit'):
        dut.T_limit.value = 250
        # We need to pulse start again? No, usually one computation.
        # Let's restart.
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        timeout = 0
        while not dut.done.value and timeout < 10000:
            await RisingEdge(dut.clk)
            timeout += 1
    
    max_p = int(dut.max_points.value)
    best_m = int(dut.best_mask.value)
    
    print(f"Max Points: {max_p}, Mask: {best_m:06b}")
    
    # Expected: 99 points, mask for task 2 (index 2 -> bit 2 set, value 4)
    # However, we also need to check if smaller indices are preferred if points are equal.
    # But here points are distinct.
    assert max_p == 99, f"Expected 99 points, got {max_p}"
    assert best_m == 0b000100, f"Expected mask 4 (task 2), got {best_m}"
    
    print("Test passed!")
