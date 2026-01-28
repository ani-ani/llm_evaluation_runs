module count_distinct_characters (
    input clk,
    input rst_n,
    input start,
    input [15:0] len,
    input [7:0] char_array[0:15],
    output reg [5:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] COUNTING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [15:0] index;
    reg [25:0] char_mask;
    reg [5:0] bit_count;
    reg [7:0] current_char;
    reg [4:0] shift_idx; // For counting bits

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            index <= 16'd0;
            char_mask <= 26'd0;
            bit_count <= 6'd0;
            current_char <= 8'd0;
            shift_idx <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 16'd0;
                    char_mask <= 26'd0;
                    bit_count <= 6'd0;
                    shift_idx <= 5'd0;
                    if (start && (len > 16'd0)) begin
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    if (index < len) begin
                        current_char <= char_array[index];
                        // Process current character
                        if ((current_char >= 8'd65) && (current_char <= 8'd90)) begin
                            // Convert uppercase to lowercase
                            if ((current_char - 8'd65) < 26) begin
                                char_mask <= char_mask | (26'd1 << (current_char - 8'd65));
                            end
                        end else if ((current_char >= 8'd97) && (current_char <= 8'd122)) begin
                            // Lowercase
                            char_mask <= char_mask | (26'd1 << (current_char - 8'd97));
                        end
                        index <= index + 16'd1;
                    end else begin
                        state <= COUNTING;
                        index <= 16'd0; // Reset for counting loop
                    end
                end

                COUNTING: begin
                    if (index < 26) begin
                        if (char_mask[index]) begin
                            bit_count <= bit_count + 6'd1;
                        end
                        index <= index + 16'd1;
                    end else begin
                        result <= bit_count;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule