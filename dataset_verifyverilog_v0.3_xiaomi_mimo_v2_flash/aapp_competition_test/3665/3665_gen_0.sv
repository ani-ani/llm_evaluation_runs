module LossySorter #(
    parameter N = 2,
    parameter M = 3,
    parameter DIGIT_WIDTH = 4
)(
    input clk,
    input rst_n,
    input start,
    input [N-1:0][M*DIGIT_WIDTH-1:0] numbers_in,
    output reg [N-1:0][M*DIGIT_WIDTH-1:0] numbers_out,
    output reg done
);

    // State declarations
    localparam [1:0] STATE_IDLE = 2'd0;
    localparam [1:0] STATE_COMPUTE = 2'd1;
    localparam [1:0] STATE_OUTPUT = 2'd2;
    localparam [1:0] STATE_DONE = 2'd3;

    // Registers
    reg [1:0] current_state;
    reg [M-1:0] digit_idx;
    reg [N-2:0] state_vector;
    reg [15:0] total_cost;
    reg [N-1:0][M*DIGIT_WIDTH-1:0] temp_numbers;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Combinational signals
    wire [DIGIT_WIDTH-1:0] orig_d0;
    wire [DIGIT_WIDTH-1:0] orig_d1;
    reg [DIGIT_WIDTH-1:0] new_d0;
    reg [DIGIT_WIDTH-1:0] new_d1;
    reg [1:0] cost_per_digit;
    reg new_state_bit;

    // Extract original digits for N=2
    assign orig_d0 = numbers_in[0][digit_idx*DIGIT_WIDTH +: DIGIT_WIDTH];
    assign orig_d1 = numbers_in[1][digit_idx*DIGIT_WIDTH +: DIGIT_WIDTH];

    // Combinational logic for optimal digit selection
    always @(*) begin
        if (N == 1) begin
            // Trivial case: single number, no sorting needed
            new_d0 = orig_d0;
            new_d1 = 4'd0;
            cost_per_digit = 2'd0;
            new_state_bit = 1'b1;
        end else if (N == 2) begin
            if (state_vector[0] == 1'b1) begin
                // Already ordered, keep original digits
                new_d0 = orig_d0;
                new_d1 = orig_d1;
                cost_per_digit = 2'd0;
                new_state_bit = 1'b1;
            end else begin
                // Still equal, need d0 <= d1
                if (orig_d0 <= orig_d1) begin
                    new_d0 = orig_d0;
                    new_d1 = orig_d1;
                    cost_per_digit = 2'd0;
                    new_state_bit = (orig_d0 < orig_d1) ? 1'b1 : 1'b0;
                end else begin
                    // orig_d0 > orig_d1, need to fix
                    // Set both to max (orig_d0) to minimize changes
                    new_d0 = orig_d0;
                    new_d1 = orig_d0;
                    cost_per_digit = (orig_d1 != orig_d0) ? 2'd1 : 2'd0;
                    new_state_bit = 1'b0;
                end
            end
        end else begin
            // For N>2, this simplified version only handles N=2
            // Default assignment to avoid latches
            new_d0 = orig_d0;
            new_d1 = orig_d1;
            cost_per_digit = 2'd0;
            new_state_bit = 1'b0;
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            done <= 1'b0;
            digit_idx <= 3'd0;
            state_vector <= 1'b0;
            total_cost <= 16'd0;
            numbers_out <= 0;
            temp_numbers <= 0;
            cycle_count <= 8'd0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    digit_idx <= 3'd0;
                    state_vector <= 1'b0;
                    total_cost <= 16'd0;
                    cycle_count <= 8'd0;
                    temp_numbers <= numbers_in;
                    if (start) begin
                        current_state <= STATE_COMPUTE;
                    end
                end

                STATE_COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Update digits for current position
                    temp_numbers[0][digit_idx*DIGIT_WIDTH +: DIGIT_WIDTH] <= new_d0;
                    temp_numbers[1][digit_idx*DIGIT_WIDTH +: DIGIT_WIDTH] <= new_d1;
                    total_cost <= total_cost + cost_per_digit;
                    state_vector[0] <= new_state_bit;

                    if (digit_idx == M - 3'd1) begin
                        current_state <= STATE_OUTPUT;
                        digit_idx <= 3'd0;
                    end else begin
                        digit_idx <= digit_idx + 3'd1;
                    end

                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        current_state <= STATE_OUTPUT;
                    end
                end

                STATE_OUTPUT: begin
                    numbers_out <= temp_numbers;
                    current_state <= STATE_DONE;
                end

                STATE_DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        current_state <= STATE_IDLE;
                    end
                end

                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule