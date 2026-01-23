module max_difference (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [4:0] num_pairs,
    input [7:0] pairs [0:7],
    output reg [7:0] max_diff,
    output reg done
);

// Internal registers
reg [2:0] state; // 3 bits for 5 states? Wait DONE is 4, so 3 bits (0-4) is okay.
reg [2:0] total_pairs;
reg [1:0] current_pair_index; // 0 to 3 → 2 bits
reg signed [7:0] a, b;
reg signed [7:0] current_diff;
reg signed [7:0] max_diff; // but the output is reg [7:0], so this is okay.

// State definitions
localparam IDLE = 3'd0,
        READ_PAIR = 3'd1,
        COMPUTE_DIFF = 3'd2,
        UPDATE_MAX = 3'd3,
        DONE = 3'd4;

// Output assignment
assign done = (state == DONE);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Asynchronous reset
        state <= IDLE;
        total_pairs <= 0;
        current_pair_index <= 0;
        max_diff <= 0;
        a <= 0;
        b <= 0;
        current_diff <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    // Capture num_pairs, min with 4
                    total_pairs <= min(num_pairs, 4);
                    current_pair_index <= 0;
                    max_diff <= 0;
                    state <= READ_PAIR;
                end else begin
                    state <= IDLE;
                end
            end
            READ_PAIR: begin
                if (current_pair_index < total_pairs) begin
                    // Read the current pair
                    a <= pairs[2*current_pair_index];
                    b <= pairs[2*current_pair_index +1];
                    state <= COMPUTE_DIFF;
                end else begin
                    state <= DONE;
                end
            end
            COMPUTE_DIFF: begin
                // Compute absolute difference
                current_diff <= (b - a) < 0 ? (a - b) : (b - a);
                state <= UPDATE_MAX;
            end
            UPDATE_MAX: begin
                // Update max_diff and transition
                max_diff <= current_diff > max_diff ? current_diff : max_diff;
                // Determine next state
                state <= (current_pair_index + 1 < total_pairs) ? READ_PAIR : DONE;
                // Increment the pair index
                current_pair_index <= current_pair_index + 1;
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end
end

endmodule