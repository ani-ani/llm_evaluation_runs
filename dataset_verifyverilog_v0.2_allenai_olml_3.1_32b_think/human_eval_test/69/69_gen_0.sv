module search_frequency (
    input clk,
    input rst_n, // active low
    input start,
    input [3:0] array_size,
    input [7:0][3:0] data,
    output reg [3:0] result,
    output reg done
);

// States
localparam IDLE = 3'd0,
        COUNT = 3'd1,
        FIND_MAX = 3'd2,
        DONE = 3'd3;

reg [2:0] state;
reg [3:0] freq [0:15];
reg [2:0] elem_idx;
reg init_done;
reg [3:0] current_v;
reg [3:0] max_val;

// Initialize registers on reset
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        elem_idx <= 0;
        init_done <= 0;
        current_v <= 0;
        max_val <= 0;
        result <= 0;
        done <= 0;
        // Initialize freq to 0 (already default, but explicit)
        freq[0] <=0; freq[1] <=0; freq[2] <=0; freq[3] <=0;
        freq[4] <=0; freq[5] <=0; freq[6] <=0; freq[7] <=0;
        freq[8] <=0; freq[9] <=0; freq[10] <=0; freq[11] <=0;
        freq[12] <=0; freq[13] <=0; freq[14] <=0; freq[15] <=0;
    end else begin
        // No action on non-reset
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        // Reset already handled above
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (state == IDLE) begin
                        state <= COUNT;
                        elem_idx <=0;
                        init_done <=0; // Initialize for COUNT phase
                    end
                end
            end
            COUNT: begin
                if (!init_done) begin
                    // Initialize frequency counters
                    freq[0] <=0; freq[1] <=0; freq[2] <=0; freq[3] <=0;
                    freq[4] <=0; freq[5] <=0; freq[6] <=0; freq[7] <=0;
                    freq[8] <=0; freq[9] <=0; freq[10] <=0; freq[11] <=0;
                    freq[12] <=0; freq[13] <=0; freq[14] <=0; freq[15] <=0;
                    init_done <=1;
                end else begin
                    if (elem_idx < array_size) begin
                        // Process current element
                        freq[ data[elem_idx][3:0] ] <= freq[ data[elem_idx][3:0] ] +1;
                        elem_idx <= elem_idx +1;
                    end else begin
                        // All elements processed, move to FIND_MAX
                        state <= FIND_MAX;
                        current_v <=15;
                        max_val <=15;
                        init_done <=1; // Not necessary, but safe
                    end
                end
            end
            FIND_MAX: begin
                if (current_v >0) begin
                    if (freq[current_v] >= current_v) begin
                        max_val <= current_v;
                    end
                    current_v <= current_v -1;
                end else begin
                    // All values checked
                    result <= max_val;
                    state <= DONE;
                end
            end
            DONE: begin
                done <=1;
            end
        endcase
    end
end

endmodule