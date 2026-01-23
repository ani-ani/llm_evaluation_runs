module find_max(
    input clk,
    input rst_n,
    input start,
    input [7:0] strings [0:3][0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COUNTING  = 2'd1;
    localparam [1:0] COMPARING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Unique count for each string
    reg [7:0] unique_count [0:3];
    reg [7:0] current_string_index;
    reg [7:0] current_char_index;
    reg [7:0] temp_count;

    // Comparison variables
    reg [7:0] max_count;
    reg [1:0] max_index;
    reg [7:0] i;

    // Character presence tracking
    reg [25:0] char_present [0:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_string_index <= 8'd0;
            current_char_index <= 8'd0;
            temp_count <= 8'd0;
            max_count <= 8'd0;
            max_index <= 2'd0;
            i <= 8'd0;

            // Initialize all registers
            integer j, k;
            for (j = 0; j < 4; j = j + 1) begin
                unique_count[j] <= 8'd0;
                char_present[j] <= 26'd0;
                for (k = 0; k < 8; k = k + 1) begin
                    result[k] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COUNTING;
                        current_string_index <= 8'd0;
                        current_char_index <= 8'd0;
                        temp_count <= 8'd0;
                        // Reset char_present for all strings
                        integer j;
                        for (j = 0; j < 4; j = j + 1) begin
                            char_present[j] <= 26'd0;
                        end
                    end
                end

                COUNTING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Process current character
                    reg [7:0] current_char;
                    current_char = strings[current_string_index][current_char_index];

                    // Check if character is valid (1-26) and not seen before
                    if (current_char != 8'd0 && current_char <= 8'd26) begin
                        if (!char_present[current_string_index][current_char - 8'd1]) begin
                            char_present[current_string_index][current_char - 8'd1] <= 1'b1;
                            temp_count <= temp_count + 8'd1;
                        end
                    end

                    // Move to next character
                    if (current_char_index == 8'd7) begin
                        // Finished current string
                        unique_count[current_string_index] <= temp_count;
                        temp_count <= 8'd0;

                        // Move to next string
                        if (current_string_index == 8'd3) begin
                            state <= COMPARING;
                            max_count <= unique_count[0];
                            max_index <= 2'd0;
                            i <= 8'd1;
                        end else begin
                            current_string_index <= current_string_index + 8'd1;
                            current_char_index <= 8'd0;
                        end
                    end else begin
                        current_char_index <= current_char_index + 8'd1;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                COMPARING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compare current string with max
                    if (unique_count[i] > max_count) begin
                        max_count <= unique_count[i];
                        max_index <= i;
                    end else if (unique_count[i] == max_count) begin
                        // Lexicographical comparison
                        reg [63:0] current_packed;
                        reg [63:0] max_packed;
                        integer k;
                        for (k = 0; k < 8; k = k + 1) begin
                            current_packed[k*8 +: 8] = strings[i][k];
                            max_packed[k*8 +: 8] = strings[max_index][k];
                        end

                        if (current_packed < max_packed) begin
                            max_index <= i;
                        end
                    end

                    // Move to next string
                    if (i == 8'd3) begin
                        state <= DONE_STATE;
                    end else begin
                        i <= i + 8'd1;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                DONE_STATE: begin
                    // Output the winning string
                    integer k;
                    for (k = 0; k < 8; k = k + 1) begin
                        result[k] <= strings[max_index][k];
                    end
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