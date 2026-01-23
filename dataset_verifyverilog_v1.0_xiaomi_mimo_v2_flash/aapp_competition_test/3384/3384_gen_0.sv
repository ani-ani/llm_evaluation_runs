module handsome_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,             // Number of digits (1-4)
    input wire [3:0] digits [0:3],    // Input digits (digits[0] is most significant)
    output reg [3:0] res1 [0:3],      // First result digits
    output reg [3:0] res2 [0:3],      // Second result digits (if two)
    output reg [1:0] count,           // Number of results (1 or 2)
    output reg done                   // Computation finished
);

// State machine states
localparam [2:0] IDLE          = 3'b000;
localparam [2:0] PREPARE       = 3'b001;
localparam [2:0] PREV_SEARCH   = 3'b010;
localparam [2:0] NEXT_SEARCH   = 3'b011;
localparam [2:0] COMPARE       = 3'b100;
localparam [2:0] FINISH        = 3'b101;

reg [2:0] state, next_state;

// Internal registers
reg [3:0] orig_digits [0:3];
reg [3:0] orig_len;
reg [31:0] orig_value;
reg [3:0] prev_digits [0:3];
reg [3:0] prev_len;
reg [31:0] prev_value;
reg [3:0] next_digits [0:3];
reg [3:0] next_len;
reg [31:0] next_value;
reg [31:0] dist_prev, dist_next;
reg [31:0] iter_count;
localparam [31:0] MAX_ITER = 1000;

// Control flags
reg search_prev;
reg search_next;
reg found_prev;
reg found_next;
reg [3:0] i;

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = PREPARE;
        end
        PREPARE: begin
            next_state = PREV_SEARCH;
        end
        PREV_SEARCH: begin
            if (found_prev || (iter_count >= MAX_ITER)) next_state = NEXT_SEARCH;
            else next_state = PREV_SEARCH;
        end
        NEXT_SEARCH: begin
            if (found_next || (iter_count >= MAX_ITER)) next_state = COMPARE;
            else next_state = NEXT_SEARCH;
        end
        COMPARE: begin
            next_state = FINISH;
        end
        FINISH: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Helper function to check if number is handsome (combinational)
function automatic [0:0] is_handsome(
    input [3:0] num_digits [0:3],
    input [3:0] length
);
    integer j;
    reg [0:0] result;
    begin
        result = 1'b1;
        if (length == 4'd0) begin
            result = 1'b0;
        end else if (length == 4'd1) begin
            result = 1'b1;
        end else begin
            for (j = 0; j < 3; j = j + 1) begin
                if (j < (length - 1)) begin
                    if ((num_digits[j] % 2) == (num_digits[j+1] % 2)) begin
                        result = 1'b0;
                    end
                end
            end
        end
        is_handsome = result;
    end
endfunction

// Helper function to convert digits to value
function automatic [31:0] digits_to_value(
    input [3:0] num_digits [0:3],
    input [3:0] length
);
    integer k;
    reg [31:0] val;
    begin
        val = 32'd0;
        for (k = 0; k < 4; k = k + 1) begin
            if (k < length) begin
                val = val * 10 + num_digits[k];
            end
        end
        digits_to_value = val;
    end
endfunction

// Main sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        orig_len <= 4'd0;
        orig_value <= 32'd0;
        prev_len <= 4'd0;
        prev_value <= 32'd0;
        next_len <= 4'd0;
        next_value <= 32'd0;
        dist_prev <= 32'd0;
        dist_next <= 32'd0;
        iter_count <= 32'd0;
        count <= 2'd0;
        done <= 1'b0;
        found_prev <= 1'b0;
        found_next <= 1'b0;
        search_prev <= 1'b0;
        search_next <= 1'b0;
        // Reset digit arrays
        for (i = 0; i < 4; i = i + 1) begin
            orig_digits[i] <= 4'd0;
            prev_digits[i] <= 4'd0;
            next_digits[i] <= 4'd0;
            res1[i] <= 4'd0;
            res2[i] <= 4'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Capture input
                    for (i = 0; i < 4; i = i + 1) begin
                        orig_digits[i] <= digits[i];
                    end
                    orig_len <= len;
                    // Initialize candidates
                    for (i = 0; i < 4; i = i + 1) begin
                        prev_digits[i] <= digits[i];
                        next_digits[i] <= digits[i];
                    end
                    prev_len <= len;
                    next_len <= len;
                end
            end

            PREPARE: begin
                // Calculate original value
                orig_value <= digits_to_value(orig_digits, orig_len);
                // Initialize search parameters
                iter_count <= 32'd0;
                found_prev <= 1'b0;
                found_next <= 1'b0;
                // Check if original is handsome
                if (is_handsome(orig_digits, orig_len)) begin
                    // If original is handsome, prev is first lower, next is first higher
                    found_prev <= 1'b1;
                    found_next <= 1'b1;
                    prev_value <= orig_value;
                    next_value <= orig_value;
                end
            end

            PREV_SEARCH: begin
                // Search for previous handsome number
                if (!found_prev) begin
                    // Decrement prev_digits
                    for (i = 4'd4; i > 0; i = i - 1) begin
                        if (i <= prev_len) begin
                            if (prev_digits[i-1] > 4'd0) begin
                                prev_digits[i-1] <= prev_digits[i-1] - 1;
                                // Reset lower digits to 9
                                for (int j = 0; j < i-1; j = j + 1) begin
                                    if (j < prev_len) prev_digits[j] <= 4'd9;
                                end
                                break;
                            end
                        end
                    end
                    // Update length (handle leading zeros)
                    if (prev_len > 4'd1 && prev_digits[0] == 4'd0) begin
                        // Find new MSB
                        if (prev_digits[1] != 4'd0) prev_len <= 4'd3;
                        else if (prev_digits[2] != 4'd0) prev_len <= 4'd2;
                        else if (prev_digits[3] != 4'd0) prev_len <= 4'd1;
                        else prev_len <= 4'd1;
                    end
                    // Check if handsome
                    if (is_handsome(prev_digits, prev_len)) begin
                        found_prev <= 1'b1;
                        prev_value <= digits_to_value(prev_digits, prev_len);
                    end
                    iter_count <= iter_count + 1;
                end
            end

            NEXT_SEARCH: begin
                // Search for next handsome number
                if (!found_next) begin
                    // Increment next_digits
                    for (i = 4'd4; i > 0; i = i - 1) begin
                        if (i <= next_len) begin
                            if (next_digits[i-1] < 4'd9) begin
                                next_digits[i-1] <= next_digits[i-1] + 1;
                                // Reset lower digits to 0
                                for (int j = 0; j < i-1; j = j + 1) begin
                                    if (j < next_len) next_digits[j] <= 4'd0;
                                end
                                break;
                            end else begin
                                // Carry over
                                if (i == 1) begin
                                    // Need to increase length (e.g., 9 -> 10)
                                    // For simplicity, assume max 4 digits, handle 9999 -> 10000 not supported
                                    next_len <= next_len + 1;
                                    for (int j = 0; j < 4; j = j + 1) begin
                                        if (j == 0) next_digits[j] <= 4'd1;
                                        else next_digits[j] <= 4'd0;
                                    end
                                end
                            end
                        end
                    end
                    // Check if handsome
                    if (is_handsome(next_digits, next_len)) begin
                        found_next <= 1'b1;
                        next_value <= digits_to_value(next_digits, next_len);
                    end
                    iter_count <= iter_count + 1;
                end
            end

            COMPARE: begin
                // Calculate distances
                if (found_prev) begin
                    dist_prev <= orig_value - prev_value;
                end else begin
                    dist_prev <= 32'hFFFFFFFF;
                end
                if (found_next) begin
                    dist_next <= next_value - orig_value;
                end else begin
                    dist_next <= 32'hFFFFFFFF;
                end
            end

            FINISH: begin
                // Output results
                done <= 1'b1;
                if (found_prev && found_next) begin
                    if (dist_prev < dist_next) begin
                        count <= 2'd1;
                        for (i = 0; i < 4; i = i + 1) begin
                            res1[i] <= (i < prev_len) ? prev_digits[i] : 4'd0;
                            res2[i] <= 4'd0;
                        end
                    end else if (dist_next < dist_prev) begin
                        count <= 2'd1;
                        for (i = 0; i < 4; i = i + 1) begin
                            res1[i] <= (i < next_len) ? next_digits[i] : 4'd0;
                            res2[i] <= 4'd0;
                        end
                    end else begin
                        count <= 2'd2;
                        for (i = 0; i < 4; i = i + 1) begin
                            res1[i] <= (i < prev_len) ? prev_digits[i] : 4'd0;
                            res2[i] <= (i < next_len) ? next_digits[i] : 4'd0;
                        end
                    end
                end else if (found_prev) begin
                    count <= 2'd1;
                    for (i = 0; i < 4; i = i + 1) begin
                        res1[i] <= (i < prev_len) ? prev_digits[i] : 4'd0;
                        res2[i] <= 4'd0;
                    end
                end else if (found_next) begin
                    count <= 2'd1;
                    for (i = 0; i < 4; i = i + 1) begin
                        res1[i] <= (i < next_len) ? next_digits[i] : 4'd0;
                        res2[i] <= 4'd0;
                    end
                end else begin
                    // No result found (shouldn't happen with proper bounds)
                    count <= 2'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        res1[i] <= 4'd0;
                        res2[i] <= 4'd0;
                    end
                end
            end

            default: begin
                // Reset to safe state
                state <= IDLE;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule