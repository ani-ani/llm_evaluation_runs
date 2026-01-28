module max_hidden_string(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] s [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FETCH   = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] UPDATE  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [3:0] i, j;
    reg [7:0] current_char;
    reg [7:0] prev_char;
    reg [15:0] max_count;
    reg [15:0] single_max;
    reg [15:0] pair_max;

    // Frequency counts for single characters (26 letters)
    reg [15:0] freq [0:25];

    // Pair counts (26x26)
    reg [15:0] pair [0:25][0:25];

    // Initialize all registers
    integer k, m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            current_char <= 8'd0;
            prev_char <= 8'd0;
            max_count <= 16'd0;
            single_max <= 16'd0;
            pair_max <= 16'd0;
            done <= 1'b0;
            result <= 16'd0;

            // Initialize frequency array
            for (k = 0; k < 26; k = k + 1) begin
                freq[k] <= 16'd0;
            end

            // Initialize pair array
            for (k = 0; k < 26; k = k + 1) begin
                for (m = 0; m < 26; m = m + 1) begin
                    pair[k][m] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= FETCH;
                        index <= 4'd0;
                        max_count <= 16'd0;
                        single_max <= 16'd0;
                        pair_max <= 16'd0;

                        // Reset frequency and pair arrays
                        for (k = 0; k < 26; k = k + 1) begin
                            freq[k] <= 16'd0;
                        end
                        for (k = 0; k < 26; k = k + 1) begin
                            for (m = 0; m < 26; m = m + 1) begin
                                pair[k][m] <= 16'd0;
                            end
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FETCH: begin
                    if (index < len) begin
                        current_char <= s[index];
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= UPDATE;
                    end
                end

                COMPUTE: begin
                    // Check if current_char is a valid lowercase letter
                    if (current_char >= 8'd97 && current_char <= 8'd122) begin
                        // Convert to 0-25 index
                        i <= current_char - 8'd97;

                        // Update single character frequency
                        freq[i] <= freq[i] + 16'd1;

                        // Update single_max if needed
                        if (freq[i] > single_max) begin
                            single_max <= freq[i];
                        end

                        // Update pair counts with previous characters
                        for (k = 0; k < 26; k = k + 1) begin
                            if (freq[k] > 16'd0) begin
                                pair[k][i] <= pair[k][i] + freq[k];
                                if (pair[k][i] > pair_max) begin
                                    pair_max <= pair[k][i];
                                end
                            end
                        end
                    end

                    // Move to next character
                    index <= index + 4'd1;
                    next_state <= FETCH;
                end

                UPDATE: begin
                    // Determine the final maximum count
                    if (single_max > pair_max) begin
                        max_count <= single_max;
                    end else begin
                        max_count <= pair_max;
                    end

                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= max_count;
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