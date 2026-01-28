module sum_uppercase (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [3:0] char_count,
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] idx;              // Current character index
    reg [10:0] sum_acc;         // 11-bit accumulator for sum
    reg processing;             // Active during computation
    
    // Combinational signals
    wire [7:0] current_char;
    wire is_uppercase;
    wire [10:0] char_ascii_val;
    wire [10:0] new_sum;
    
    // Extract current character
    assign current_char = char_array[idx];
    
    // Uppercase detection logic
    // Uppercase letters: 0x41 (A) to 0x5A (Z)
    // Check: (char & 0x5F) >= 0x41 AND (char & 0x5F) <= 0x5A
    wire [7:0] normalized_char;
    assign normalized_char = current_char & 8'h5F;
    assign is_uppercase = (normalized_char >= 8'h41) && (normalized_char <= 8'h5A);
    
    // ASCII value (only valid if uppercase, else 0)
    assign char_ascii_val = is_uppercase ? {3'd0, current_char} : 11'd0;
    
    // New sum calculation
    assign new_sum = sum_acc + char_ascii_val;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE : IDLE;
            COMPUTE: next_state = (idx >= char_count) ? DONE_STATE : COMPUTE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            idx <= 4'd0;
            sum_acc <= 11'd0;
            result <= 16'd0;
            done <= 1'b0;
            processing <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    // Clear done and prepare for new operation
                    done <= 1'b0;
                    processing <= 1'b0;
                    idx <= 4'd0;
                    sum_acc <= 11'd0;
                    result <= 16'd0;
                    
                    // Start processing on start pulse
                    if (start) begin
                        processing <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    // Increment index for next cycle
                    if (processing) begin
                        idx <= idx + 4'd1;
                        
                        // Accumulate sum
                        sum_acc <= new_sum;
                    end
                end
                
                DONE_STATE: begin
                    // Pad 11-bit sum to 16-bit output
                    result <= {5'd0, sum_acc};
                    done <= 1'b1;
                    processing <= 1'b0;
                    idx <= 4'd0;
                    sum_acc <= 11'd0;
                end
                
                default: begin
                    state <= IDLE;
                    idx <= 4'd0;
                    sum_acc <= 11'd0;
                    result <= 16'd0;
                    done <= 1'b0;
                    processing <= 1'b0;
                end
            endcase
        end
    end
endmodule