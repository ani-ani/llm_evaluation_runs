module max_subarray_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str_data,
    input wire [3:0] str_len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [3:0] char_index;
    reg [15:0] current_sum;
    reg [15:0] max_sum;
    reg [3:0] len_reg;
    
    // Internal signals
    wire [7:0] current_char;
    wire signed [15:0] weight;
    wire signed [15:0] new_sum;
    
    // Extract current 8-bit character from 128-bit vector
    assign current_char = str_data[char_index * 8 +: 8];
    
    // Determine weight: '1' (0x31) -> -1, '0' (0x30) -> +1
    // Note: ASCII '0' = 0x30, '1' = 0x31
    assign weight = (current_char == 8'h31) ? -16'sd1 : 16'sd1;
    
    // Calculate new sum
    assign new_sum = current_sum + weight;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            char_index <= 4'd0;
            current_sum <= 16'sd0;
            max_sum <= 16'sd0;
            len_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        len_reg <= str_len;
                        char_index <= 4'd0;
                        current_sum <= 16'sd0;
                        max_sum <= 16'sd0;
                        result <= 16'sd0;
                        if (str_len == 4'd0) begin
                            state <= DONE;
                        end else begin
                            state <= PROCESSING;
                        end
                    end
                end
                
                PROCESSING: begin
                    // Kadane's algorithm
                    if (current_sum < 16'sd0) begin
                        current_sum <= weight;
                    end else begin
                        current_sum <= new_sum;
                    end
                    
                    // Update max_sum
                    if (new_sum > max_sum) begin
                        max_sum <= new_sum;
                    end else if (current_sum < 16'sd0 && weight > max_sum) begin
                        max_sum <= weight;
                    end
                    
                    // Check for completion
                    if (char_index >= len_reg - 4'd1) begin
                        result <= (new_sum > max_sum) ? new_sum : max_sum;
                        state <= DONE;
                    end else begin
                        char_index <= char_index + 4'd1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'sd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule