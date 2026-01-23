module scary_subarray_counter(
    input clk,
    input rst_n,
    input start,
    input [2:0] array_length,
    input [7:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    output reg [7:0] scary_count,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [7:0] count, next_count;
    reg [7:0] scary_count_reg, next_scary_count;
    reg done_reg, next_done;

    // Processing counters
    reg [2:0] l, next_l; // Start position
    reg [2:0] len, next_len; // Odd length (1,3,5...)
    reg [2:0] i, next_i; // Inner loop index for comparison
    reg [3:0] smaller_count, next_smaller_count; // Count elements smaller than p[l]

    // Array element storage for easier indexing
    wire [7:0] p [0:7];
    assign p[0] = p_0;
    assign p[1] = p_1;
    assign p[2] = p_2;
    assign p[3] = p_3;
    assign p[4] = p_4;
    assign p[5] = p_5;
    assign p[6] = p_6;
    assign p[7] = p_7;

    // Current subarray boundaries
    wire [2:0] end_pos;
    assign end_pos = l + len - 1;

    // Combinational logic for state transition and next values
    always @(*) begin
        next_state = state;
        next_count = count;
        next_scary_count = scary_count_reg;
        next_done = done_reg;
        next_l = l;
        next_len = len;
        next_i = i;
        next_smaller_count = smaller_count;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_scary_count = 8'd0;
                next_l = 3'd0;
                next_len = 3'd1;
                next_i = 3'd0;
                next_smaller_count = 4'd0;
                if (start) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                // Check if current subarray [l, l+len-1] is valid
                if (end_pos < array_length) begin
                    // Compare p[i] with p[l] to count smaller elements
                    // We iterate i from l+1 to end_pos
                    if (i == l) begin
                        // Start of comparison loop, initialize smaller count
                        next_smaller_count = 4'd0;
                        next_i = l + 1;
                    end else if (i <= end_pos) begin
                        // Compare p[i] with p[l]
                        if (p[i] < p[l]) begin
                            next_smaller_count = smaller_count + 1;
                        end
                        next_i = i + 1;
                    end else begin
                        // Comparison complete, check if scary
                        // Length is len = 2k+1, so median index is k
                        // Median index k = (len - 1) / 2
                        // We need smaller_count == k
                        if (smaller_count == ((len - 1) >> 1)) begin
                            next_scary_count = scary_count_reg + 1;
                        end
                        // Move to next odd length
                        next_len = len + 2;
                        next_i = l; // Reset i for next loop
                        // If next len is too big, move to next start position
                        if ((l + len + 2) > array_length) begin
                            next_l = l + 1;
                            next_len = 3'd1;
                            // Check if all start positions done
                            if (l + 1 >= array_length) begin
                                next_state = DONE;
                            end
                        end
                    end
                end else begin
                    // Current len is too large for current l, move to next l
                    next_l = l + 1;
                    next_len = 3'd1;
                    next_i = l + 1; // Reset i
                    if (l + 1 >= array_length) begin
                        next_state = DONE;
                    end
                end
            end

            DONE: begin
                next_done = 1'b1;
                if (!start) begin // Wait for start to go low before accepting new start
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 8'd0;
            scary_count <= 8'd0;
            done <= 1'b0;
            l <= 3'd0;
            len <= 3'd1;
            i <= 3'd0;
            smaller_count <= 4'd0;
        end else begin
            state <= next_state;
            count <= next_count;
            scary_count <= next_scary_count;
            done <= next_done;
            l <= next_l;
            len <= next_len;
            i <= next_i;
            smaller_count <= next_smaller_count;
        end
    end

endmodule
