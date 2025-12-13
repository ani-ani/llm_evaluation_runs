import cocotb
from cocotb.triggers import Timer

def build_flat_matrix(n, edges):
    adj = [[0]*16 for _ in range(16)]
    for u, v in edges:
        adj[u][v] = 1
        adj[v][u] = 1
    flat = 0
    for i in range(16):
        row_val = 0
        for j in range(16):
            if i < n and j < n and adj[i][j]:
                row_val |= (1 << j)
        flat |= row_val << (i * 16)
    return flat

@cocotb.test()
async def test_path_counter(dut):
    test_cases = [(3, [(0,1),(0,2)], 2), (5, [(1,0),(0,4),(2,0),(3,2)], 8), (10, [(0,1),(1,2),(1,3),(0,4),(2,5),(1,6),(6,7),(4,8),(4,9)], 24), (8, [(0,1),(1,2),(2,3),(3,4),(4,5),(5,0),(1,0)], 12)]
    passed = 0
    for n, edges, expected in test_cases:
        dut.N.value = n
        dut.adjacency_matrix_flat.value = build_flat_matrix(n, edges)
        await Timer(1, units='ns')
        observed = dut.count.value.integer
        if observed == expected:
            passed += 1
        else:
            dut._log.error("Test failed: N=%d Expected %d Got %d" % (n, expected, observed))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))