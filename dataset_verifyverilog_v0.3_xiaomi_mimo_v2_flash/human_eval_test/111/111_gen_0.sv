module histogram (
    input clk,
    input rst_n,
    input start,
    input [7:0] str_in [0:7],
    input [2:0] valid_chars,
    output reg [7:0] result_char,
    output reg [7:0] result_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] READ    = 3'd1;
    localparam [2:0] COUNT   = 3'd2;
    localparam [2:0] FIND_MAX = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Constants
    localparam [7:0] MAX_INDEX = 8'd7;
    localparam [7:0] MAX_CYCLES = 8'd50;
    localparam [7:0] CHAR_COUNT = 8'd27; // 26 letters + space

    // State and control registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [7:0] idx;
    reg [7:0] temp_char;
    reg [7:0] count;
    reg [7:0] max_count_reg;
    reg [7:0] max_char_reg;

    // Storage array for 27 characters (a-z and space)
    // Index 0: space (0x20)
    // Index 1-26: 'a' to 'z' (0x61 to 0x7A)
    reg [7:0] counts [0:26];

    integer i;

    // Helper function to convert ASCII to index
    function automatic [7:0] ascii_to_idx(input [7:0] char);
        begin
            if (char == 8'h20) begin
                ascii_to_idx = 8'd0; // Space maps to index 0
            end else if (char >= 8'h61 && char <= 8'h7A) begin
                ascii_to_idx = char - 8'h60; // 'a' -> 1, 'b' -> 2, etc.
            end else begin
                ascii_to_idx = 8'd0; // Default to space index for invalid
            end
        end
    endfunction

    // State Machine and Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_char <= 8'd0;
            result_count <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            idx <= 8'd0;
            temp_char <= 8'd0;
            count <= 8'd0;
            max_count_reg <= 8'd0;
            max_char_reg <= 8'd0;
            for (i = 0; i < 27; i = i + 1) begin
                counts[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    idx <= 8'd0;
                    if (start) begin
                        state <= READ;
                    end else begin
                        state <= IDLE;
                    end
                end

                READ: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Read all valid characters into processing buffer
                    if (idx < valid_chars) begin
                        // Get index for current character
                        if (str_in[idx] >= 8'h61 && str_in[idx] <= 8'h7A) begin
                            // Valid character, increment count
                            counts[ascii_to_idx(str_in[idx])] <= counts[ascii_to_idx(str_in[idx])] + 8'd1;
                        end
                        // Note: Space and other characters are ignored in counting
                        idx <= idx + 8'd1;
                        state <= READ;
                    end else begin
                        idx <= 8'd0;
                        state <= FIND_MAX;
                    end
                end

                FIND_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Iterate through all 27 characters to find max
                    if (idx < CHAR_COUNT) begin
                        if (counts[idx] > max_count_reg) begin
                            max_count_reg <= counts[idx];
                            // Convert index back to ASCII
                            if (idx == 8'd0) begin
                                max_char_reg <= 8'h20; // Space
                            end else begin
                                max_char_reg <= idx + 8'h60; // 'a' to 'z'
                            end
                        end
                        idx <= idx + 8'd1;
                        state <= FIND_MAX;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result_char <= max_char_reg;
                    result_count <= max_count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule