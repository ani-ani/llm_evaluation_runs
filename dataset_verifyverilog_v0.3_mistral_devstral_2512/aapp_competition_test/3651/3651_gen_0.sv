module tsp_portal_solver(
    input clk,
    input rst_n,
    input start,
    input [9:0] x0, y0, z0,
    input [9:0] x1, y1, z1,
    input [9:0] x2, y2, z2,
    input [9:0] x3, y3, z3,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Registered inputs
    reg [9:0] x0_reg, y0_reg, z0_reg;
    reg [9:0] x1_reg, y1_reg, z1_reg;
    reg [9:0] x2_reg, y2_reg, z2_reg;
    reg [9:0] x3_reg, y3_reg, z3_reg;

    // Distance calculations (Manhattan)
    wire [10:0] d01 = (x0_reg > x1_reg) ? (x0_reg - x1_reg) : (x1_reg - x0_reg);
    wire [10:0] d02 = (x0_reg > x2_reg) ? (x0_reg - x2_reg) : (x2_reg - x0_reg);
    wire [10:0] d03 = (x0_reg > x3_reg) ? (x0_reg - x3_reg) : (x3_reg - x0_reg);
    wire [10:0] d12 = (x1_reg > x2_reg) ? (x1_reg - x2_reg) : (x2_reg - x1_reg);
    wire [10:0] d13 = (x1_reg > x3_reg) ? (x1_reg - x3_reg) : (x3_reg - x1_reg);
    wire [10:0] d23 = (x2_reg > x3_reg) ? (x2_reg - x3_reg) : (x3_reg - x2_reg);

    wire [10:0] d01_y = (y0_reg > y1_reg) ? (y0_reg - y1_reg) : (y1_reg - y0_reg);
    wire [10:0] d02_y = (y0_reg > y2_reg) ? (y0_reg - y2_reg) : (y2_reg - y0_reg);
    wire [10:0] d03_y = (y0_reg > y3_reg) ? (y0_reg - y3_reg) : (y3_reg - y0_reg);
    wire [10:0] d12_y = (y1_reg > y2_reg) ? (y1_reg - y2_reg) : (y2_reg - y1_reg);
    wire [10:0] d13_y = (y1_reg > y3_reg) ? (y1_reg - y3_reg) : (y3_reg - y1_reg);
    wire [10:0] d23_y = (y2_reg > y3_reg) ? (y2_reg - y3_reg) : (y3_reg - y2_reg);

    wire [10:0] d01_z = (z0_reg > z1_reg) ? (z0_reg - z1_reg) : (z1_reg - z0_reg);
    wire [10:0] d02_z = (z0_reg > z2_reg) ? (z0_reg - z2_reg) : (z2_reg - z0_reg);
    wire [10:0] d03_z = (z0_reg > z3_reg) ? (z0_reg - z3_reg) : (z3_reg - z0_reg);
    wire [10:0] d12_z = (z1_reg > z2_reg) ? (z1_reg - z2_reg) : (z2_reg - z1_reg);
    wire [10:0] d13_z = (z1_reg > z3_reg) ? (z1_reg - z3_reg) : (z3_reg - z1_reg);
    wire [10:0] d23_z = (z2_reg > z3_reg) ? (z2_reg - z3_reg) : (z3_reg - z2_reg);

    wire [10:0] d01_total = d01 + d01_y + d01_z;
    wire [10:0] d02_total = d02 + d02_y + d02_z;
    wire [10:0] d03_total = d03 + d03_y + d03_z;
    wire [10:0] d12_total = d12 + d12_y + d12_z;
    wire [10:0] d13_total = d13 + d13_y + d13_z;
    wire [10:0] d23_total = d23 + d23_y + d23_z;

    // Permutation costs and savings
    wire [15:0] cost0 = d01_total + d12_total + d23_total; // 0->1->2->3
    wire [15:0] cost1 = d01_total + d13_total + d32_total; // 0->1->3->2
    wire [15:0] cost2 = d02_total + d21_total + d13_total; // 0->2->1->3
    wire [15:0] cost3 = d02_total + d23_total + d31_total; // 0->2->3->1
    wire [15:0] cost4 = d03_total + d31_total + d12_total; // 0->3->1->2
    wire [15:0] cost5 = d03_total + d32_total + d21_total; // 0->3->2->1

    // Portal savings (maximum matching weight)
    wire [10:0] savings0 = (d01_total < d23_total) ? d01_total : d23_total; // 0-1 and 2-3
    wire [10:0] savings1 = (d01_total < d32_total) ? d01_total : d32_total; // 0-1 and 3-2
    wire [10:0] savings2 = (d02_total < d13_total) ? d02_total : d13_total; // 0-2 and 1-3
    wire [10:0] savings3 = (d02_total < d31_total) ? d02_total : d31_total; // 0-2 and 3-1
    wire [10:0] savings4 = (d03_total < d12_total) ? d03_total : d12_total; // 0-3 and 1-2
    wire [10:0] savings5 = (d03_total < d21_total) ? d03_total : d21_total; // 0-3 and 2-1

    // Final costs with portal savings
    wire [15:0] final_cost0 = cost0 - savings0;
    wire [15:0] final_cost1 = cost1 - savings1;
    wire [15:0] final_cost2 = cost2 - savings2;
    wire [15:0] final_cost3 = cost3 - savings3;
    wire [15:0] final_cost4 = cost4 - savings4;
    wire [15:0] final_cost5 = cost5 - savings5;

    // Find minimum cost
    wire [15:0] min_cost;
    always @(*) begin
        min_cost = final_cost0;
        if (final_cost1 < min_cost) min_cost = final_cost1;
        if (final_cost2 < min_cost) min_cost = final_cost2;
        if (final_cost3 < min_cost) min_cost = final_cost3;
        if (final_cost4 < min_cost) min_cost = final_cost4;
        if (final_cost5 < min_cost) min_cost = final_cost5;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            x0_reg <= 10'd0;
            y0_reg <= 10'd0;
            z0_reg <= 10'd0;
            x1_reg <= 10'd0;
            y1_reg <= 10'd0;
            z1_reg <= 10'd0;
            x2_reg <= 10'd0;
            y2_reg <= 10'd0;
            z2_reg <= 10'd0;
            x3_reg <= 10'd0;
            y3_reg <= 10'd0;
            z3_reg <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Capture inputs
                        x0_reg <= x0;
                        y0_reg <= y0;
                        z0_reg <= z0;
                        x1_reg <= x1;
                        y1_reg <= y1;
                        z1_reg <= z1;
                        x2_reg <= x2;
                        y2_reg <= y2;
                        z2_reg <= z2;
                        x3_reg <= x3;
                        y3_reg <= y3;
                        z3_reg <= z3;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= min_cost;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule