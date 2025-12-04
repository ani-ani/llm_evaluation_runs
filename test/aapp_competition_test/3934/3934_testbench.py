import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tree_check(dut):
    test_cases = [
        # Input 2-node tree (should pass: YES)
        (
            [0,1,0,0,0,0,0,0],
            [
                [0,1,0,0,0,0,0,0],
                [1,0,0,0,0,0,0,0],
                [0]*8, [0]*8, [0]*8, [0]*8, [0]*8, [0]*8
            ],
            1
        ),
        # Input 3-node chain (node1 degree=2 - should fail: NO)
        (
            [0,1,2,0,0,0,0,0],
            [
                [0,1,0,0,0,0,0,0],
                [1,0,1,0,0,0,0,0],
                [0,1,0,0,0,0,0,0],
                [0]*8, [0]*8, [0]*8, [0]*8, [0]*8
            ],
            0
        ),
        # Input 5-node star with a chain (node2 degree=2 - NO)
        (
            [0,1,2,3,4,0,0,0],
            [
                [0,1,1,1,0,0,0,0],
                [1,0,1,0,0,0,0,0], # node1 gets degree=2 from edges 0 and 2
                [1,1,0,0,1,0,0,0],
                [1,0,0,0,0,0,0,0],
                [0,0,1,0,0,0,0,0],
                [0]*8, [0]*8, [0]*8
            ],
            0
        ),
        # Input 6-node OK tree (all degrees !=2)
        (
            [0,1,2,3,4,5,0,0],
            [
                [0,1,1,1,0,0,0,0],
                [1,0,0,0,1,1,0,0],
                [1,0,0,0,0,0,0,0],
                [1,0,0,0,0,0,0,0],
                [0,1,0,0,0,0,0,0],
                [0,1,0,0,0,0,0,0],
                [0]*8, [0]*8
            ],
            1
        )
    ]
    passed = 0
    for (nodes, adj_mat, expected) in test_cases:
        for i in range(8):
            dut.node_id[i].value = nodes[i]
            for j in range(8):
                dut.adj_matrix[i][j].value = adj_mat[i][j]
        await Timer(1, units='ns')
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {expected} got {dut.result.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")