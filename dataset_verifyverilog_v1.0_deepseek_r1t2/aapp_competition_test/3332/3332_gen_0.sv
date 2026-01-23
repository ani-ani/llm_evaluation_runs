module stream_scheduler (
    input clk,
    input rst_n,
    input start,
    input [7:0] s0, d0, p0,
    input [7:0] s1, d1, p1,
    input [7:0] s2, d2, p2,
    input [7:0] s3, d3, p3,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_ST = 3'd3;
    
    reg [2:0] state;
    reg [3:0] current_subset;
    reg [15:0] current_max;
    reg [15:0] sum_temp;
    reg feasible_temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Stored inputs
    reg [7:0] s_reg[0:3];
    reg [7:0] d_reg[0:3];
    reg [7:0] p_reg[0:3];
    reg [15:0] e_reg[0:3];
    
    // Pair crossings
    wire [5:0] pair_crossings;
    
    // Section 1: Crossing checks
    assign pair_crossings[0] = ((s_reg[0] < s_reg[1]) & (s_reg[1] < e_reg[0]) & (e_reg[0] < e_reg[1])) ||
                               ((s_reg[1] < s_reg[0]) & (s_reg[0] < e_reg[1]) & (e_reg[1] < e_reg[0]));
    assign pair_crossings[1] = ((s_reg[0] < s_reg[2]) & (s_reg[2] < e_reg[0]) & (e_reg[0] < e_reg[2])) ||
                               ((s_reg[2] < s_reg[0]) & (s_reg[0] < e_reg[2]) & (e_reg[2] < e_reg[0]));
    assign pair_crossings[2] = ((s_reg[0] < s_reg[3]) & (s_reg[3] < e_reg[0]) & (e_reg[0] < e_reg[3])) ||
                               ((s_reg[3] < s_reg[0]) & (s_reg[0] < e_reg[3]) & (e_reg[3] < e_reg[0]));
    assign pair_crossings[3] = ((s_reg[1] < s_reg[2]) & (s_reg[2] < e_reg[1]) & (e_reg[1] < e_reg[2])) ||
                               ((s_reg[2] < s_reg[1]) & (s_reg[1] < e_reg[2]) & (e_reg[2] < e_reg[1]));
    assign pair_crossings[4] = ((s_reg[1] < s_reg[3]) & (s_reg[3] < e_reg[1]) & (e_reg[1] < e_reg[3])) ||
                               ((s_reg[3] < s_reg[1]) & (s_reg[1] < e_reg[3]) & (e_reg[3] < e_reg[1]));
    assign pair_crossings[5] = ((s_reg[2] < s_reg[3]) & (s_reg[3] < e_reg[2]) & (e_reg[2] < e_reg[3])) ||
                               ((s_reg[3] < s_reg[2]) & (s_reg[2] < e_reg[3]) & (e_reg[3] < e_reg[2]));
    
    // Section 2: Feasibility logic
    assign feasible_temp = ~(
        ((current_subset[0] & current_subset[1]) ? pair_crossings[0] : 1'b0) |
        ((current_subset[0] & current_subset[2]) ? pair_crossings[1] : 1'b0) |
        ((current_subset[0] & current_subset[3]) ? pair_crossings[2] : 1'b0) |
        ((current_subset[1] & current_subset[2]) ? pair_crossings[3] : 1'b0) |
        ((current_subset[1]  & current_subset[3]) ? pair_crossings[4] : 1'b0) |
        ((current_subset[2] & current_subset[3]) ? pair_crossings[5] : 1'b0)
    );
    
    // Section 3: Priority summation logic
    assign sum_temp = 
        (current_subset[0] ? {8'd0, p_reg[0]} : 16'd0) +
        (current_subset[1] ? {8'd0, p_reg[1]} : 16'd0) +
        (current_subset[2] ? {8'd0, p_reg[2]} : 16'd0) +
        (current_subset[3] ? {8'd0, p_reg[3]} : 16'd0);
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 16'd0;
            state <= IDLE;
            current_subset <= 4'd0;
            current_max <= 16'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 4; i = i + 1) begin
                s_reg[i] <= 8'd0;
                d_reg[i] <= 8'd0;
                p_reg[i] <= 8'd0;
                e_reg[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    current_max <= 16'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    s_reg[0] <= s0; d_reg[0] <= d0; p_reg[0] <= p0; e_reg[0] <= {8'd0, s0} + {8'd0, d0};
                    s_reg[1] <= s1; d_reg[1] <= d1; p_reg[1] <= p1; e_reg[1] <= {8'd0, s1} + {8'd0, d1};
                    s_reg[2] <= s2; d_reg[2] <= d2; p_reg[2] <= p2; e_reg[2] <= {8'd0, s2} + {8'd0, d2};
                    s_reg[3] <= s3; d_reg[3] <= d3; p_reg[3] <= p3; e_reg[3] <= {8'd0, s3} + {8'd0, d3};
                    current_subset <= 4'd0;
                    cycle_count <= 8'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Update max if feasible
                    if (feasible_temp && (sum_temp > current_max)) begin
                        current_max <= sum_temp;
                    end
                    
                    // Increment subset or complete
                    if ((current_subset == 4'hF) || (cycle_count >= MAX_CYCLES)) begin
                        state <= DONE_ST;
                    end else begin
                        current_subset <= current_subset + 4'd1;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    result <= current_max;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule