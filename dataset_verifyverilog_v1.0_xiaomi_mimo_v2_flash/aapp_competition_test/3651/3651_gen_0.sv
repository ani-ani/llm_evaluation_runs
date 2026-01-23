module tsp_portal_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] x0, y0, z0,
    input wire [9:0] x1, y1, z1,
    input wire [9:0] x2, y2, z2,
    input wire [9:0] x3, y3, z3,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Input registers
    reg [9:0] reg_x0, reg_y0, reg_z0;
    reg [9:0] reg_x1, reg_y1, reg_z1;
    reg [9:0] reg_x2, reg_y2, reg_z2;
    reg [9:0] reg_x3, reg_y3, reg_z3;
    
    // Combinational distance calculations
    wire [10:0] dist01, dist02, dist03;
    wire [10:0] dist12, dist13, dist23;
    
    // Manhattan distance between planets
    assign dist01 = {1'b0, reg_x0} + {1'b0, reg_x1} + {1'b0, reg_y0} + {1'b0, reg_y1} + {1'b0, reg_z0} + {1'b0, reg_z1};
    assign dist02 = {1'b0, reg_x0} + {1'b0, reg_x2} + {1'b0, reg_y0} + {1'b0, reg_y2} + {1'b0, reg_z0} + {1'b0, reg_z2};
    assign dist03 = {1'b0, reg_x0} + {1'b0, reg_x3} + {1'b0, reg_y0} + {1'b0, reg_y3} + {1'b0, reg_z0} + {1'b0, reg_z3};
    assign dist12 = {1'b0, reg_x1} + {1'b0, reg_x2} + {1'b0, reg_y1} + {1'b0, reg_y2} + {1'b0, reg_z1} + {1'b0, reg_z2};
    assign dist13 = {1'b0, reg_x1} + {1'b0, reg_x3} + {1'b0, reg_y1} + {1'b0, reg_y3} + {1'b0, reg_z1} + {1'b0, reg_z3};
    assign dist23 = {1'b0, reg_x2} + {1'b0, reg_x3} + {1'b0, reg_y2} + {1'b0, reg_y3} + {1'b0, reg_z2} + {1'b0, reg_z3};
    
    // Permutation indices (0,1,2,3)
    // Planets 1,2,3 are in permutation - planet 0 is fixed at start
    // 6 permutations:
    // P0: 1-2-3, P1: 1-3-2, P2: 2-1-3, P3: 2-3-1, P4: 3-1-2, P5: 3-2-1
    
    // Permutation edge sets (edges: 0->p0, p0->p1, p1->p2, p2->0)
    // We need to find max matching between edges (0-1, 0-2, 0-3, 1-2, 1-3, 2-3)
    // and perimeter edges (0-1, 1-2, 2-3, 3-0) depending on permutation
    
    // Edge to distance mapping
    wire [10:0] edge_01;
    wire [10:0] edge_02;
    wire [10:0] edge_03;
    wire [10:0] edge_12;
    wire [10:0] edge_13;
    wire [10:0] edge_23;
    
    assign edge_01 = dist01;
    assign edge_02 = dist02;
    assign edge_03 = dist03;
    assign edge_12 = dist12;
    assign edge_13 = dist13;
    assign edge_23 = dist23;
    
    // Permutation costs and savings
    reg [10:0] perm_cost [0:5];
    reg [10:0] perm_savings [0:5];
    
    // Compute for each permutation
    // P0: 0-1-2-3-0, edges: 01,12,23,30
    always @(*) begin
        perm_cost[0] = edge_01 + edge_12 + edge_23 + edge_03;
        // Matching: can match (0-1) with (0-1) or (1-2) with (1-2) or (2-3) with (2-3)
        // Max matching weight = max(edge_01, edge_12, edge_23)
        if (edge_01 >= edge_12 && edge_01 >= edge_23) begin
            perm_savings[0] = edge_01;
        end else if (edge_12 >= edge_23) begin
            perm_savings[0] = edge_12;
        end else begin
            perm_savings[0] = edge_23;
        end
    end
    
    // P1: 0-1-3-2-0, edges: 01,13,32,20
    always @(*) begin
        perm_cost[1] = edge_01 + edge_13 + edge_23 + edge_02;
        // Matching: (0-1) with (0-1), (1-3) with (1-3), (2-3) with (3-2)
        // Max = max(edge_01, edge_13, edge_23)
        if (edge_01 >= edge_13 && edge_01 >= edge_23) begin
            perm_savings[1] = edge_01;
        end else if (edge_13 >= edge_23) begin
            perm_savings[1] = edge_13;
        end else begin
            perm_savings[1] = edge_23;
        end
    end
    
    // P2: 0-2-1-3-0, edges: 02,21,13,30
    always @(*) begin
        perm_cost[2] = edge_02 + edge_12 + edge_13 + edge_03;
        // Matching: (0-2) with (0-2), (1-2) with (2-1), (1-3) with (1-3)
        // Max = max(edge_02, edge_12, edge_13)
        if (edge_02 >= edge_12 && edge_02 >= edge_13) begin
            perm_savings[2] = edge_02;
        end else if (edge_12 >= edge_13) begin
            perm_savings[2] = edge_12;
        end else begin
            perm_savings[2] = edge_13;
        end
    end
    
    // P3: 0-2-3-1-0, edges: 02,23,31,10
    always @(*) begin
        perm_cost[3] = edge_02 + edge_23 + edge_13 + edge_01;
        // Matching: (0-2) with (0-2), (2-3) with (2-3), (1-3) with (3-1)
        // Max = max(edge_02, edge_23, edge_13)
        if (edge_02 >= edge_23 && edge_02 >= edge_13) begin
            perm_savings[3] = edge_02;
        end else if (edge_23 >= edge_13) begin
            perm_savings[3] = edge_23;
        end else begin
            perm_savings[3] = edge_13;
        end
    end
    
    // P4: 0-3-1-2-0, edges: 03,31,12,20
    always @(*) begin
        perm_cost[4] = edge_03 + edge_13 + edge_12 + edge_02;
        // Matching: (0-3) with (0-3), (1-3) with (3-1), (1-2) with (1-2)
        // Max = max(edge_03, edge_13, edge_12)
        if (edge_03 >= edge_13 && edge_03 >= edge_12) begin
            perm_savings[4] = edge_03;
        end else if (edge_13 >= edge_12) begin
            perm_savings[4] = edge_13;
        end else begin
            perm_savings[4] = edge_12;
        end
    end
    
    // P5: 0-3-2-1-0, edges: 03,32,21,10
    always @(*) begin
        perm_cost[5] = edge_03 + edge_23 + edge_12 + edge_01;
        // Matching: (0-3) with (0-3), (2-3) with (3-2), (1-2) with (2-1)
        // Max = max(edge_03, edge_23, edge_12)
        if (edge_03 >= edge_23 && edge_03 >= edge_12) begin
            perm_savings[5] = edge_03;
        end else if (edge_23 >= edge_12) begin
            perm_savings[5] = edge_23;
        end else begin
            perm_savings[5] = edge_12;
        end
    end
    
    // Find minimum cost = min over all permutations of (cost - savings)
    reg [10:0] min_cost;
    always @(*) begin
        min_cost = perm_cost[0] - perm_savings[0];
        if (perm_cost[1] - perm_savings[1] < min_cost)
            min_cost = perm_cost[1] - perm_savings[1];
        if (perm_cost[2] - perm_savings[2] < min_cost)
            min_cost = perm_cost[2] - perm_savings[2];
        if (perm_cost[3] - perm_savings[3] < min_cost)
            min_cost = perm_cost[3] - perm_savings[3];
        if (perm_cost[4] - perm_savings[4] < min_cost)
            min_cost = perm_cost[4] - perm_savings[4];
        if (perm_cost[5] - perm_savings[5] < min_cost)
            min_cost = perm_cost[5] - perm_savings[5];
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            reg_x0 <= 10'd0; reg_y0 <= 10'd0; reg_z0 <= 10'd0;
            reg_x1 <= 10'd0; reg_y1 <= 10'd0; reg_z1 <= 10'd0;
            reg_x2 <= 10'd0; reg_y2 <= 10'd0; reg_z2 <= 10'd0;
            reg_x3 <= 10'd0; reg_y3 <= 10'd0; reg_z3 <= 10'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        reg_x0 <= x0; reg_y0 <= y0; reg_z0 <= z0;
                        reg_x1 <= x1; reg_y1 <= y1; reg_z1 <= z1;
                        reg_x2 <= x2; reg_y2 <= y2; reg_z2 <= z2;
                        reg_x3 <= x3; reg_y3 <= y3; reg_z3 <= z3;
                    end
                end
                
                COMPUTE: begin
                    result <= {5'd0, min_cost[10:0]};
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            
            COMPUTE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule