module LNDS_Module(
    input clk,
    input rst_n,
    input start,
    input [15:0] seq,
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    reg [3:0] current_index;
    
    // DP state registers
    reg [7:0] state_1;   // Prefix of 1s
    reg [7:0] state_2;   // Prefix of 2s
    reg [7:0] state_12;  // Pattern 1...2
    reg [7:0] state_21;  // Pattern 2...1
    reg [7:0] max_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_index <= 4'd0;
            state_1 <= 8'd0;
            state_2 <= 8'd0;
            state_12 <= 8'd0;
            state_21 <= 8'd0;
            max_result <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    current_index <= 4'd0;
                    state_1 <= 8'd0;
                    state_2 <= 8'd0;
                    state_12 <= 8'd0;
                    state_21 <= 8'd0;
                    max_result <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current element
                    if (current_index < len) begin
                        if (seq[current_index] == 1'b0) begin
                            // Value is 1
                            state_1 <= state_1 + 8'd1;
                            state_12 <= (state_2 > state_12) ? (state_2 + 8'd1) : (state_12 + 8'd1);
                        end else begin
                            // Value is 2
                            state_2 <= (state_1 > state_2) ? (state_1 + 8'd1) : (state_2 + 8'd1);
                            state_21 <= (state_12 > state_21) ? (state_12 + 8'd1) : (state_21 + 8'd1);
                        end
                        
                        // Update max_result
                        max_result <= (state_1 > max_result) ? state_1 : max_result;
                        max_result <= (state_2 > max_result) ? state_2 : max_result;
                        max_result <= (state_12 > max_result) ? state_12 : max_result;
                        max_result <= (state_21 > max_result) ? state_21 : max_result;
                        
                        current_index <= current_index + 4'd1;
                    end
                    
                    // Check if processing is complete
                    if (current_index >= len) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= max_result;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule