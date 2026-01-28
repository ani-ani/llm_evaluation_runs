module count_distinct_characters(
    input clk,
    input rst_n,
    input start,
    input [15:0] len,
    input [7:0] char_array [0:15],
    output reg [5:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] COUNTING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] index;  // 4 bits for 0-15
    reg [25:0] seen_mask;  // 26 bits for a-z
    reg [5:0] bit_count;  // 6 bits for 0-26
    reg [7:0] current_char;
    reg [7:0] lower_char;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            seen_mask <= 26'd0;
            bit_count <= 6'd0;
            result <= 6'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end

            PROCESSING: begin
                if (index == len - 1) begin
                    next_state = COUNTING;
                end else begin
                    next_state = PROCESSING;
                end
            end

            COUNTING: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 4'd0;
            seen_mask <= 26'd0;
            bit_count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    index <= 4'd0;
                    seen_mask <= 26'd0;
                    bit_count <= 6'd0;
                end

                PROCESSING: begin
                    current_char = char_array[index];
                    // Convert to lowercase
                    if (current_char >= 8'd65 && current_char <= 8'd90) begin
                        lower_char = current_char + 8'd32;
                    end else begin
                        lower_char = current_char;
                    end
                    // Check if it's a lowercase letter
                    if (lower_char >= 8'd97 && lower_char <= 8'd122) begin
                        // Set corresponding bit in mask
                        seen_mask[lower_char - 8'd97] = 1'b1;
                    end
                    index <= index + 4'd1;
                end

                COUNTING: begin
                    // Count set bits in seen_mask
                    bit_count = 6'd0;
                    integer i;
                    for (i = 0; i < 26; i = i + 1) begin
                        if (seen_mask[i]) begin
                            bit_count = bit_count + 6'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= bit_count;
                    done <= 1'b1;
                end

                default: begin
                    index <= 4'd0;
                    seen_mask <= 26'd0;
                    bit_count <= 6'd0;
                end
            endcase
        end
    end

    // Clear done signal after one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule