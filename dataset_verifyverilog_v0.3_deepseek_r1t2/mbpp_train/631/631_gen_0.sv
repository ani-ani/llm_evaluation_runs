module replace_spaces(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [4:0] len,
    output reg [7:0] result_array [0:15],
    output reg done,
    output reg valid
);
    // State definitions
    localparam [1:0] 
        IDLE = 2'd0,
        PROCESS = 2'd1,
        FINISHED = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;
    reg [4:0] index;
    reg [4:0] stored_len;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            index <= 5'd0;
            stored_len <= 5'd0;
            
            // Initialize result array
            for (i = 0; i < 16; i = i + 1) begin
                result_array[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    
                    if (start && len != 5'd0) begin
                        stored_len <= len;
                        index <= 5'd0;
                        
                        // Preload data
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < len) result_array[i] <= char_array[i];
                            else result_array[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESS: begin
                    if (index < stored_len) begin
                        // Swap spaces/underscores
                        case (result_array[index])
                            8'd32: result_array[index] <= 8'd95;  // Space → Underscore
                            8'd95: result_array[index] <= 8'd32;  // Underscore → Space
                            default: ; // No change
                        endcase
                        index <= index + 5'd1;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    if (start && len != 5'd0) next_state = PROCESS;
            PROCESS: if (index >= stored_len) next_state = FINISHED;
            FINISHED: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
endmodule