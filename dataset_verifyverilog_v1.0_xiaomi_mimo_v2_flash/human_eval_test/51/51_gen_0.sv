module remove_vowels (
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:7],
    output reg [7:0] result [0:7],
    output reg [3:0] result_len,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state;
    reg [2:0] index;  // 0 to 7 for input array access
    reg [3:0] out_index;  // 0 to 7 for output array access
    reg [7:0] temp_char;
    reg is_vowel;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            index <= 3'd0;
            out_index <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'h00;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_len <= 4'd0;
                    index <= 3'd0;
                    out_index <= 4'd0;
                    // Reset output array
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= 8'h00;
                    end
                    if (start) begin
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // Read character from input array
                    temp_char <= str[index];
                    
                    // Check if vowel (lowercase only)
                    is_vowel <= ((str[index] == 8'h61) ||  // 'a'
                                (str[index] == 8'h65) ||  // 'e'
                                (str[index] == 8'h69) ||  // 'i'
                                (str[index] == 8'h6F) ||  // 'o'
                                (str[index] == 8'h75));   // 'u'
                    
                    // Logic to write to output if not vowel
                    // We need to handle the writing in the same cycle
                    if (!is_vowel && str[index] != 8'h00) begin
                        result[out_index] <= str[index];
                        out_index <= out_index + 4'd1;
                    end
                    
                    // Increment input index
                    index <= index + 3'd1;
                    
                    // Check if done with processing 8 characters
                    if (index == 3'd7) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result_len <= out_index;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule