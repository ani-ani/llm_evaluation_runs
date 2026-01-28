module LNDS(
    input clk,
    input rst_n,
    input start,
    input [15:0] seq,
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations for FSM
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] UPDATE    = 2'd2;
    localparam [1:0] FINISH    = 2'd3;
    
    reg [1:0] state;
    reg [3:0] index;           // Current element index (0-15)
    reg current_bit;           // Extracted bit from seq
    
    // DP state registers (8-bit to handle max length 16)
    reg [7:0] state_1;         // All 1s
    reg [7:0] state_2;         // All 2s  
    reg [7:0] state_12;        // Pattern 1...2
    reg [7:0] state_21;        // Pattern 2...1
    
    // Temporary values for updates
    reg [7:0] max_1_2;
    reg [7:0] max_12_21;
    
    // Update max of result at each step
    reg [7:0] max_result;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 4'd0;
            current_bit <= 1'b0;
            state_1 <= 8'd0;
            state_2 <= 8'd0;
            state_12 <= 8'd0;
            state_21 <= 8'd0;
            max_result <= 8'd0;
            max_1_2 <= 8'd0;
            max_12_21 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        state_1 <= 8'd0;
                        state_2 <= 8'd0;
                        state_12 <= 8'd0;
                        state_21 <= 8'd0;
                        max_result <= 8'd0;
                    end
                end
                
                PROCESS: begin
                    // Extract current bit from seq
                    current_bit <= seq[index];
                    // Move to update state
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    // Calculate max values based on current bit
                    if (current_bit == 1'b0) begin
                        // Value is 1
                        max_1_2 <= state_2;
                        max_12_21 <= (state_2 > state_12) ? state_2 : state_12;
                        
                        state_1 <= state_1 + 8'd1;
                        state_12 <= ((state_2 > state_12) ? state_2 : state_12) + 8'd1;
                    end else begin
                        // Value is 2
                        max_1_2 <= (state_1 > state_2) ? state_1 : state_2;
                        max_12_21 <= state_12;
                        
                        state_2 <= ((state_1 > state_2) ? state_1 : state_2) + 8'd1;
                        state_21 <= (state_12 > state_21) ? state_12 : state_21;
                        state_21 <= state_21 + 8'd1;
                    end
                    
                    // Update max_result after state updates
                    // For value 1: max of state_1 and state_12 (newly computed)
                    // For value 2: max of state_2 and state_21 (newly computed)
                    if (current_bit == 1'b0) begin
                        if (state_1 + 8'd1 > (max_12_21 + 8'd1)) begin
                            max_result <= state_1 + 8'd1;
                        end else begin
                            max_result <= max_12_21 + 8'd1;
                        end
                    end else begin
                        if (max_1_2 + 8'd1 > (state_21 + 8'd1)) begin
                            max_result <= max_1_2 + 8'd1;
                        end else begin
                            max_result <= state_21 + 8'd1;
                        end
                    end
                    
                    // Check if done processing all elements
                    if (index == len - 4'd1) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                        state <= PROCESS;
                    end
                end
                
                FINISH: begin
                    result <= max_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule