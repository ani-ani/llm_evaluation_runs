module histogram(
    input clk,
    input rst_n,
    input start,
    input [7:0] str_in [0:7],
    input [2:0] valid_chars,
    output reg [7:0] result_char,
    output reg [7:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ      = 3'd1;
    localparam [2:0] COUNT     = 3'd2;
    localparam [2:0] FIND_MAX  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] char_counts [0:26]; // 26 letters + space (index 0 = space, 1-26 = 'a'-'z')
    reg [7:0] current_char;
    reg [7:0] max_count;
    reg [7:0] max_char;
    reg [3:0] char_index;
    reg [3:0] str_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Character to index mapping
    function [3:0] char_to_index;
        input [7:0] c;
        begin
            if (c == 8'd32) // space
                char_to_index = 4'd0;
            else if (c >= 8'd97 && c <= 8'd122) // 'a'-'z'
                char_to_index = c - 8'd96; // 'a' -> 1, 'b' -> 2, etc.
            else
                char_to_index = 4'd0; // default to space
        end
    endfunction

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_char <= 8'd0;
            result_count <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            str_index <= 4'd0;
            char_index <= 4'd0;
            max_count <= 8'd0;
            max_char <= 8'd0;
            current_char <= 8'd0;
            for (char_index = 0; char_index < 27; char_index = char_index + 1) begin
                char_counts[char_index] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= READ;
                        str_index <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (str_index < valid_chars) begin
                        current_char <= str_in[str_index];
                        next_state <= COUNT;
                    end else begin
                        next_state <= FIND_MAX;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    char_index <= char_to_index(current_char);
                    char_counts[char_index] <= char_counts[char_index] + 8'd1;
                    str_index <= str_index + 4'd1;
                    next_state <= READ;
                end

                FIND_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_index < 27) begin
                        if (char_counts[char_index] > max_count) begin
                            max_count <= char_counts[char_index];
                            if (char_index == 4'd0)
                                max_char <= 8'd32; // space
                            else
                                max_char <= char_index + 8'd96; // convert back to ASCII
                        end
                        char_index <= char_index + 4'd1;
                    end else begin
                        next_state <= DONE_STATE;
                        char_index <= 4'd0;
                    end
                end

                DONE_STATE: begin
                    result_char <= max_char;
                    result_count <= max_count;
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