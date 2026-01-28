module knapsack_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [3:0] k,
    input [8:0] s_0,
    input [8:0] s_1,
    input [8:0] s_2,
    input [8:0] s_3,
    input [8:0] s_4,
    input [8:0] s_5,
    input [8:0] s_6,
    input [8:0] s_7,
    input [31:0] v_0,
    input [31:0] v_1,
    input [31:0] v_2,
    input [31:0] v_3,
    input [31:0] v_4,
    input [31:0] v_5,
    input [31:0] v_6,
    input [31:0] v_7,
    output reg [31:0] result_1,
    output reg [31:0] result_2,
    output reg [31:0] result_3,
    output reg [31:0] result_4,
    output reg [31:0] result_5,
    output reg [31:0] result_6,
    output reg [31:0] result_7,
    output reg [31:0] result_8,
    output reg [31:0] result_9,
    output reg [31:0] result_10,
    output reg [31:0] result_11,
    output reg [31:0] result_12,
    output reg [31:0] result_13,
    output reg [31:0] result_14,
    output reg [31:0] result_15,
    output reg [31:0] result_16,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RUN = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Index registers
    reg [3:0] jewel_idx;      // 0 to 7
    reg [3:0] capacity_idx;   // 0 to 16
    reg [8:0] jewel_size;
    reg [31:0] jewel_value;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;
    
    // DP table - 17 registers for capacities 0-16
    reg [31:0] dp_0;
    reg [31:0] dp_1;
    reg [31:0] dp_2;
    reg [31:0] dp_3;
    reg [31:0] dp_4;
    reg [31:0] dp_5;
    reg [31:0] dp_6;
    reg [31:0] dp_7;
    reg [31:0] dp_8;
    reg [31:0] dp_9;
    reg [31:0] dp_10;
    reg [31:0] dp_11;
    reg [31:0] dp_12;
    reg [31:0] dp_13;
    reg [31:0] dp_14;
    reg [31:0] dp_15;
    reg [31:0] dp_16;
    
    // Temporary register for DP update
    reg [31:0] new_value;
    reg [31:0] current_value;
    reg [31:0] prev_value;
    
    // Input capture registers
    reg [2:0] n_reg;
    reg [3:0] k_reg;
    reg [8:0] s_reg [0:7];
    reg [31:0] v_reg [0:7];
    
    integer i;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            jewel_idx <= 4'd0;
            capacity_idx <= 4'd0;
            jewel_size <= 9'd0;
            jewel_value <= 32'd0;
            new_value <= 32'd0;
            current_value <= 32'd0;
            prev_value <= 32'd0;
            
            // Reset DP table
            dp_0 <= 32'd0;
            dp_1 <= 32'd0;
            dp_2 <= 32'd0;
            dp_3 <= 32'd0;
            dp_4 <= 32'd0;
            dp_5 <= 32'd0;
            dp_6 <= 32'd0;
            dp_7 <= 32'd0;
            dp_8 <= 32'd0;
            dp_9 <= 32'd0;
            dp_10 <= 32'd0;
            dp_11 <= 32'd0;
            dp_12 <= 32'd0;
            dp_13 <= 32'd0;
            dp_14 <= 32'd0;
            dp_15 <= 32'd0;
            dp_16 <= 32'd0;
            
            // Reset output results
            result_1 <= 32'd0;
            result_2 <= 32'd0;
            result_3 <= 32'd0;
            result_4 <= 32'd0;
            result_5 <= 32'd0;
            result_6 <= 32'd0;
            result_7 <= 32'd0;
            result_8 <= 32'd0;
            result_9 <= 32'd0;
            result_10 <= 32'd0;
            result_11 <= 32'd0;
            result_12 <= 32'd0;
            result_13 <= 32'd0;
            result_14 <= 32'd0;
            result_15 <= 32'd0;
            result_16 <= 32'd0;
            
            // Reset input capture registers
            n_reg <= 3'd0;
            k_reg <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                s_reg[i] <= 9'd0;
                v_reg[i] <= 32'd0;
            end
            
        end else begin
            
            case (state)
                
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    jewel_idx <= 4'd0;
                    capacity_idx <= 4'd0;
                    
                    if (start) begin
                        // Capture inputs
                        n_reg <= n;
                        k_reg <= k;
                        s_reg[0] <= s_0;
                        s_reg[1] <= s_1;
                        s_reg[2] <= s_2;
                        s_reg[3] <= s_3;
                        s_reg[4] <= s_4;
                        s_reg[5] <= s_5;
                        s_reg[6] <= s_6;
                        s_reg[7] <= s_7;
                        v_reg[0] <= v_0;
                        v_reg[1] <= v_1;
                        v_reg[2] <= v_2;
                        v_reg[3] <= v_3;
                        v_reg[4] <= v_4;
                        v_reg[5] <= v_5;
                        v_reg[6] <= v_6;
                        v_reg[7] <= v_7;
                        
                        // Reset DP table to all zeros
                        dp_0 <= 32'd0;
                        dp_1 <= 32'd0;
                        dp_2 <= 32'd0;
                        dp_3 <= 32'd0;
                        dp_4 <= 32'd0;
                        dp_5 <= 32'd0;
                        dp_6 <= 32'd0;
                        dp_7 <= 32'd0;
                        dp_8 <= 32'd0;
                        dp_9 <= 32'd0;
                        dp_10 <= 32'd0;
                        dp_11 <= 32'd0;
                        dp_12 <= 32'd0;
                        dp_13 <= 32'd0;
                        dp_14 <= 32'd0;
                        dp_15 <= 32'd0;
                        dp_16 <= 32'd0;
                        
                        next_state <= RUN;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                RUN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current jewel data
                    case (jewel_idx)
                        4'd0: begin jewel_size <= s_reg[0]; jewel_value <= v_reg[0]; end
                        4'd1: begin jewel_size <= s_reg[1]; jewel_value <= v_reg[1]; end
                        4'd2: begin jewel_size <= s_reg[2]; jewel_value <= v_reg[2]; end
                        4'd3: begin jewel_size <= s_reg[3]; jewel_value <= v_reg[3]; end
                        4'd4: begin jewel_size <= s_reg[4]; jewel_value <= v_reg[4]; end
                        4'd5: begin jewel_size <= s_reg[5]; jewel_value <= v_reg[5]; end
                        4'd6: begin jewel_size <= s_reg[6]; jewel_value <= v_reg[6]; end
                        4'd7: begin jewel_size <= s_reg[7]; jewel_value <= v_reg[7]; end
                        default: begin jewel_size <= 9'd0; jewel_value <= 32'd0; end
                    endcase
                    
                    // Get current capacity value
                    case (capacity_idx)
                        4'd0: current_value <= dp_0;
                        4'd1: current_value <= dp_1;
                        4'd2: current_value <= dp_2;
                        4'd3: current_value <= dp_3;
                        4'd4: current_value <= dp_4;
                        4'd5: current_value <= dp_5;
                        4'd6: current_value <= dp_6;
                        4'd7: current_value <= dp_7;
                        4'd8: current_value <= dp_8;
                        4'd9: current_value <= dp_9;
                        4'd10: current_value <= dp_10;
                        4'd11: current_value <= dp_11;
                        4'd12: current_value <= dp_12;
                        4'd13: current_value <= dp_13;
                        4'd14: current_value <= dp_14;
                        4'd15: current_value <= dp_15;
                        default: current_value <= dp_16;
                    endcase
                    
                    // Get previous capacity value (capacity - jewel_size)
                    if (capacity_idx >= jewel_size[3:0]) begin
                        case (capacity_idx - jewel_size[3:0])
                            4'd0: prev_value <= dp_0;
                            4'd1: prev_value <= dp_1;
                            4'd2: prev_value <= dp_2;
                            4'd3: prev_value <= dp_3;
                            4'd4: prev_value <= dp_4;
                            4'd5: prev_value <= dp_5;
                            4'd6: prev_value <= dp_6;
                            4'd7: prev_value <= dp_7;
                            4'd8: prev_value <= dp_8;
                            4'd9: prev_value <= dp_9;
                            4'd10: prev_value <= dp_10;
                            4'd11: prev_value <= dp_11;
                            4'd12: prev_value <= dp_12;
                            4'd13: prev_value <= dp_13;
                            4'd14: prev_value <= dp_14;
                            4'd15: prev_value <= dp_15;
                            default: prev_value <= dp_16;
                        endcase
                    end else begin
                        prev_value <= 32'd0;
                    end
                    
                    // Calculate new value
                    if (capacity_idx >= jewel_size[3:0]) begin
                        new_value <= (prev_value + jewel_value > current_value) ? (prev_value + jewel_value) : current_value;
                    end else begin
                        new_value <= current_value;
                    end
                    
                    // Update DP table after one cycle delay
                    // (This happens in the next cycle when values are stable)
                    // Actually, let's update based on calculated values
                    if (capacity_idx == 4'd0) dp_0 <= new_value;
                    if (capacity_idx == 4'd1) dp_1 <= new_value;
                    if (capacity_idx == 4'd2) dp_2 <= new_value;
                    if (capacity_idx == 4'd3) dp_3 <= new_value;
                    if (capacity_idx == 4'd4) dp_4 <= new_value;
                    if (capacity_idx == 4'd5) dp_5 <= new_value;
                    if (capacity_idx == 4'd6) dp_6 <= new_value;
                    if (capacity_idx == 4'd7) dp_7 <= new_value;
                    if (capacity_idx == 4'd8) dp_8 <= new_value;
                    if (capacity_idx == 4'd9) dp_9 <= new_value;
                    if (capacity_idx == 4'd10) dp_10 <= new_value;
                    if (capacity_idx == 4'd11) dp_11 <= new_value;
                    if (capacity_idx == 4'd12) dp_12 <= new_value;
                    if (capacity_idx == 4'd13) dp_13 <= new_value;
                    if (capacity_idx == 4'd14) dp_14 <= new_value;
                    if (capacity_idx == 4'd15) dp_15 <= new_value;
                    if (capacity_idx == 4'd16) dp_16 <= new_value;
                    
                    // Increment indices
                    if (capacity_idx < k_reg) begin
                        capacity_idx <= capacity_idx + 4'd1;
                    end else begin
                        capacity_idx <= 4'd0;
                        if (jewel_idx < n_reg - 3'd1) begin
                            jewel_idx <= jewel_idx + 4'd1;
                        end else begin
                            // All jewels processed
                            // Copy results to outputs
                            result_1 <= dp_1;
                            result_2 <= dp_2;
                            result_3 <= dp_3;
                            result_4 <= dp_4;
                            result_5 <= dp_5;
                            result_6 <= dp_6;
                            result_7 <= dp_7;
                            result_8 <= dp_8;
                            result_9 <= dp_9;
                            result_10 <= dp_10;
                            result_11 <= dp_11;
                            result_12 <= dp_12;
                            result_13 <= dp_13;
                            result_14 <= dp_14;
                            result_15 <= dp_15;
                            result_16 <= dp_16;
                            
                            next_state <= DONE_STATE;
                        end
                    end
                    
                    // Check for timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        // Copy results and finish
                        result_1 <= dp_1;
                        result_2 <= dp_2;
                        result_3 <= dp_3;
                        result_4 <= dp_4;
                        result_5 <= dp_5;
                        result_6 <= dp_6;
                        result_7 <= dp_7;
                        result_8 <= dp_8;
                        result_9 <= dp_9;
                        result_10 <= dp_10;
                        result_11 <= dp_11;
                        result_12 <= dp_12;
                        result_13 <= dp_13;
                        result_14 <= dp_14;
                        result_15 <= dp_15;
                        result_16 <= dp_16;
                        next_state <= DONE_STATE;
                    end
                    
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
                
            endcase
            
        end
    end

endmodule