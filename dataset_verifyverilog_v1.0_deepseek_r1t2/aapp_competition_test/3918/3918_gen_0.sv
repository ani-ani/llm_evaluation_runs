module min_error (
    input clk,
    input rst_n,
    input start,
    input [15:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input [15:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    input [7:0] k1,
    input [7:0] k2,
    output reg [63:0] result,
    output reg done
);

    // State machine definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] COMPUTE_DIFF = 3'd1;
    localparam [2:0] FIND_MAX     = 3'd2;
    localparam [2:0] UPDATE       = 3'd3;
    localparam [2:0] SUM          = 3'd4;
    localparam [2:0] DONE_ST      = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [15:0] diff [0:7];
    reg [8:0]  ops_remaining;
    reg [2:0]  idx;
    reg [15:0] max_val;
    reg [2:0]  max_idx;
    reg [63:0] sum;
    
    integer i; // For-loop index
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
            ops_remaining <= 9'd0;
            idx <= 3'd0;
            max_val <= 16'd0;
            max_idx <= 3'd0;
            sum <= 64'd0;
            for (i = 0; i < 8; i = i + 1)
                diff[i] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize operations counter (k1 + k2)
                        ops_remaining <= {1'b0, k1} + {1'b0, k2};
                        idx <= 3'd0;
                        state <= COMPUTE_DIFF;
                    end
                end
                
                COMPUTE_DIFF: begin
                    // Compute absolute difference for current index
                    case (idx)
                        3'd0: diff[0] <= ($signed(a_0) > $signed(b_0)) ? (a_0 - b_0) : (b_0 - a_0);
                        3'd1: diff[1] <= ($signed(a_1) > $signed(b_1)) ? (a_1 - b_1) : (b_1 - a_1);
                        3'd2: diff[2] <= ($signed(a_2) > $signed(b_2)) ? (a_2 - b_2) : (b_2 - a_2);
                        3'd3: diff[3] <= ($signed(a_3) > $signed(b_3)) ? (a_3 - b_3) : (b_3 - a_3);
                        3'd4: diff[4] <= ($signed(a_4) > $signed(b_4)) ? (a_4 - b_4) : (b_4 - a_4);
                        3'd5: diff[5] <= ($signed(a_5) > $signed(b_5)) ? (a_5 - b_5) : (b_5 - a_5);
                        3'd6: diff[6] <= ($signed(a_6) > $signed(b_6)) ? (a_6 - b_6) : (b_6 - a_6);
                        3'd7: diff[7] <= ($signed(a_7) > $signed(b_7)) ? (a_7 - b_7) : (b_7 - a_7);
                    endcase
                    
                    // Move to next element
                    if (idx == 3'd7) begin
                        idx <= 3'd0;
                        max_val <= 16'd0;
                        state <= FIND_MAX;
                    end else begin
                        idx <= idx + 3'd1;
                    end
                end
                
                FIND_MAX: begin
                    // Find maximum difference
                    if (diff[idx] > max_val) begin
                        max_val <= diff[idx];
                        max_idx <= idx;
                    end
                    
                    // Continue scanning
                    if (idx == 3'd7) begin
                        state <= UPDATE;
                    end else begin
                        idx <= idx + 3'd1;
                    end
                end
                
                UPDATE: begin
                    if (ops_remaining != 9'd0) begin
                        // Decrement current maximum (clamp at 0)
                        if (max_val != 16'd0) begin
                            diff[max_idx] <= max_val - 16'd1;
                        end
                        
                        // Decrement operations counter
                        ops_remaining <= ops_remaining - 9'd1;
                        
                        // Prepare for next iteration
                        idx <= 3'd0;
                        max_val <= 16'd0;
                        state <= FIND_MAX;
                    end else begin
                        // All operations complete - calculate sum
                        sum <= 64'd0;
                        idx <= 3'd0;
                        state <= SUM;
                    end
                end
                
                SUM: begin
                    if (idx < 3'd7) begin
                        sum <= sum + (diff[idx] * diff[idx]);
                        idx <= idx + 3'd1;
                    end else begin
                        // Store final result and finish
                        sum <= sum + (diff[7] * diff[7]);
                        result <= sum + (diff[7] * diff[7]);
                        state <= DONE_ST;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
