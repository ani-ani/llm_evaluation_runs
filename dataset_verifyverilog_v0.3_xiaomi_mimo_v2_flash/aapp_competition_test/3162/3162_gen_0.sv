module pixel_activation_counter (
    input clk,
    input rst_n,
    input start,
    input [17:0] vertical_t [0:7],
    input [17:0] vertical_m [0:7],
    input [17:0] vertical_a [0:7],
    input [7:0] vertical_valid,
    input [17:0] horizontal_t [0:7],
    input [17:0] horizontal_m [0:7],
    input [17:0] horizontal_a [0:7],
    input [7:0] horizontal_valid,
    output reg [5:0] count,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers and wires for computation
    reg [1:0] state;
    reg [2:0] v_idx;  // 0-7 for vertical index
    reg [2:0] h_idx;  // 0-7 for horizontal index
    reg [5:0] next_count;
    
    // Intermediate signed calculation registers
    reg signed [18:0] d;  // t_v - t_h
    reg signed [18:0] k;  // a_v - a_h
    reg signed [18:0] k_minus_mv;  // k - m_v
    reg signed [18:0] k_plus_mh;   // k + m_h
    
    // Condition flags
    wire cond1;  // d > k - m_v
    wire cond2;  // d < k + m_h
    wire both_valid;
    wire pair_activation;

    // Combinational calculations
    // d = t_v - t_h (signed)
    assign d = $signed(vertical_t[v_idx]) - $signed(horizontal_t[h_idx]);
    
    // k = a_v - a_h (signed)
    assign k = $signed(vertical_a[v_idx]) - $signed(horizontal_a[h_idx]);
    
    // k - m_v
    assign k_minus_mv = k - $signed(vertical_m[v_idx]);
    
    // k + m_h
    assign k_plus_mh = k + $signed(horizontal_m[h_idx]);
    
    // Condition check
    assign cond1 = (d > k_minus_mv);
    assign cond2 = (d < k_plus_mh);
    
    // Both pulses must be valid
    assign both_valid = vertical_valid[v_idx] & horizontal_valid[h_idx];
    
    // Activation condition
    assign pair_activation = both_valid & cond1 & cond2;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 6'd0;
            done <= 1'b0;
            v_idx <= 3'd0;
            h_idx <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        v_idx <= 3'd0;
                        h_idx <= 3'd0;
                        count <= 6'd0;
                    end
                end
                
                COMPUTE: begin
                    // Check current pair
                    if (pair_activation) begin
                        count <= count + 6'd1;
                    end
                    
                    // Move to next pair
                    if (h_idx == 3'd7) begin
                        h_idx <= 3'd0;
                        if (v_idx == 3'd7) begin
                            // All 64 pairs processed
                            state <= FINISH;
                        end else begin
                            v_idx <= v_idx + 3'd1;
                        end
                    end else begin
                        h_idx <= h_idx + 3'd1;
                    end
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