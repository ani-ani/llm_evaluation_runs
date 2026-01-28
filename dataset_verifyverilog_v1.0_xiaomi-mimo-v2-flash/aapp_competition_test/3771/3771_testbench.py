import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_frog_min_cut(dut):
    # Configure max grid size (scaled down for FPGA constraints)
    MAX_H = 16
    MAX_W = 16
    
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Helper to reset DUT
    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Helper to compute expected result (max flow) using Python (simplified Dinic)
    def compute_max_flow(grid, H, W):
        # Locate S and T
        s_r, s_c, t_r, t_c = -1, -1, -1, -1
        leaves = []
        for r in range(H):
            for c in range(W):
                ch = grid[r][c]
                if ch == 'S':
                    s_r, s_c = r, c
                elif ch == 'T':
                    t_r, t_c = r, c
                elif ch == 'o':
                    leaves.append((r, c))
        
        if s_r == t_r or s_c == t_c:
            return -1
        
        N = H + W + 2
        source = 0
        sink = N - 1
        
        # Capacities as a matrix
        cap = [[0] * N for _ in range(N)]
        INF = 10**9
        
        # Source to S rows/cols
        cap[source][1 + s_r] = INF
        cap[source][1 + H + s_c] = INF
        # T to Sink
        cap[1 + t_r][sink] = INF
        cap[1 + H + t_c][sink] = INF
        
        # Bidirectional edges for 'o' leaves
        for (r, c) in leaves:
            u = 1 + r
            v = 1 + H + c
            cap[u][v] = 1
            cap[v][u] = 1
        
        # Dinic's algorithm
        def bfs():
            level = [-1] * N
            q = [source]
            level[source] = 0
            while q:
                u = q.pop(0)
                for v in range(N):
                    if cap[u][v] > 0 and level[v] < 0:
                        level[v] = level[u] + 1
                        q.append(v)
            return level
        
        def dfs(u, flow, level, ptr):
            if u == sink:
                return flow
            for v in range(ptr[u], N):
                ptr[u] = v
                if cap[u][v] > 0 and level[u] < level[v]:
                    pushed = dfs(v, min(flow, cap[u][v]), level, ptr)
                    if pushed > 0:
                        cap[u][v] -= pushed
                        cap[v][u] += pushed
                        return pushed
            return 0
        
        flow = 0
        while True:
            level = bfs()
            if level[sink] < 0:
                break
            ptr = [0] * N
            while True:
                pushed = dfs(source, INF, level, ptr)
                if pushed == 0:
                    break
                flow += pushed
        
        return flow if flow < INF else -1
    
    # Test cases
    test_cases = [
        {
            'H': 3, 'W': 3,
            'grid': [
                "S.o",
                ".o.",
                "o.T"
            ],
            'expected': 2
        },
        {
            'H': 2, 'W': 2,
            'grid': [
                "ST",
                ".."
            ],
            'expected': -1  # S and T share row 0
        },
        {
            'H': 1, 'W': 3,
            'grid': ["SoT"],
            'expected': -1  # S and T share row 0, col 0 and 2
        }
    ]
    
    for i, tc in enumerate(test_cases):
        H = min(tc['H'], MAX_H)
        W = min(tc['W'], MAX_W)
        
        # Compute expected result (scaled down for small H, W)
        expected = compute_max_flow(tc['grid'], H, W)
        
        dut._log.info(f"Test case {i+1}: H={H}, W={W}, Expected={expected}")
        
        # Reset DUT
        await reset()
        
        # Write grid to DUT (assuming DUT has inputs for grid data)
        # For this testbench, we assume the DUT reads from a ROM or external interface.
        # Here, we will simulate the DUT's behavior by writing to appropriate inputs if available.
        # If the DUT has inputs like 'grid_row', 'grid_col', 'grid_char', we set them.
        # For simplicity, we'll assume a simplified interface where we pass the entire grid as inputs.
        # Since Verilog doesn't have variable-length arrays, we assume fixed MAX_H, MAX_W.
        
        # Example: Set inputs for each cell
        for r in range(MAX_H):
            for c in range(MAX_W):
                if r < H and c < W:
                    ch = tc['grid'][r][c]
                    # Convert char to 8-bit value
                    val = ord(ch)
                    # Assuming input signals like 'grid_in_r_c' exist
                    # This is a simulation: check if DUT has such ports
                    if hasattr(dut, f'grid_in_{r}_{c}'):
                        getattr(dut, f'grid_in_{r}_{c}').value = clamp_to_width(val, 8)
                    else:
                        # Fallback: Assume DUT has a serial interface or separate signals
                        pass
                else:
                    # Pad with '.'
                    if hasattr(dut, f'grid_in_{r}_{c}'):
                        getattr(dut, f'grid_in_{r}_{c}').value = ord('.')
        
        # Set H and W inputs (if available)
        if hasattr(dut, 'h_in'):
            dut.h_in.value = H
        if hasattr(dut, 'w_in'):
            dut.w_in.value = W
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        done = False
        for _ in range(10000):  # Max cycles
            await RisingEdge(dut.clk)
            if hasattr(dut, 'done') and dut.done.value == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {i+1}: DUT did not assert done within 10000 cycles")
        
        # Read result
        if hasattr(dut, 'result'):
            actual = int(dut.result.value)
            if actual != expected:
                raise TestFailure(f"Test {i+1}: Expected {expected}, got {actual}")
            dut._log.info(f"Test {i+1}: Passed (result={actual})")
        else:
            raise TestFailure("DUT missing 'result' output")
    
    dut._log.info("All tests passed!")