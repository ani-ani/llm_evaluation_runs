module lossy_sort(
    input clk,
    input rst_n,
    input start,
    input [1:0] n,           // number of values (0-4, representing 1-5)
    input [2:0] m,           // digits per number (0-2, representing 1-3) - not used in logic but kept for interface
    input [9:0] current_number,
    input load,
    output reg [9:0] result_number,
    output reg [7:0] changes_count,
    output reg done
);

// State definitions
localparam IDLE = 3'b000;
localparam LOAD = 3'b001;
localparam COMPUTE = 3'b010;
localparam OUTPUT = 3'b011;
localparam DONE = 3'b100;

// Internal registers and wires
reg [2:0] state;
reg [2:0] next_state;
reg [2:0] position_counter;      // 0-4
reg [2:0] next_position_counter;
reg [9:0] prev_value;
reg [9:0] next_prev_value;
reg [7:0] total_changes;
reg [7:0] next_total_changes;
reg [9:0] current_input;
reg [9:0] next_current_input;
reg [9:0] current_output;
reg [9:0] next_current_output;
reg [7:0] result_changes;
reg [7:0] next_result_changes;

// For computation: brute force search from prev_value to 999
reg [9:0] candidate;
reg [9:0] next_candidate;
reg [9:0] best_candidate;
reg [7:0] best_changes;
reg [7:0] next_best_candidate;
reg [7:0] next_best_changes;

// Combinational helper: digit changes between two 3-digit numbers
function [7:0] digit_changes;
    input [9:0] a;
    input [9:0] b;
    reg [3:0] a_d0, a_d1, a_d2;
    reg [3:0] b_d0, b_d1, b_d2;
    begin
        // Extract digits
        a_d2 = a / 100;
        a_d1 = (a / 10) % 10;
        a_d0 = a % 10;
        b_d2 = b / 100;
        b_d1 = (b / 10) % 10;
        b_d0 = b % 10;
        
        digit_changes = (a_d2 !== b_d2 ? 1 : 0) + 
                        (a_d1 !== b_d1 ? 1 : 0) + 
                        (a_d0 !== b_d0 ? 1 : 0);
    end
endfunction

// State transition and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        position_counter <= 3'b0;
        prev_value <= 10'b0;
        total_changes <= 8'b0;
        current_input <= 10'b0;
        current_output <= 10'b0;
        result_changes <= 8'b0;
        candidate <= 10'b0;
        best_candidate <= 10'b0;
        best_changes <= 8'b0;
        result_number <= 10'b0;
        changes_count <= 8'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        position_counter <= next_position_counter;
        prev_value <= next_prev_value;
        total_changes <= next_total_changes;
        current_input <= next_current_input;
        current_output <= next_current_output;
        result_changes <= next_result_changes;
        candidate <= next_candidate;
        best_candidate <= next_best_candidate;
        best_changes <= next_best_changes;
        result_number <= (state == OUTPUT) ? current_output : result_number;
        changes_count <= (state == DONE) ? total_changes : changes_count;
        done <= (state == DONE) ? 1'b1 : 1'b0;
    end
end

// Combinational next state logic
always @(*) begin
    // Defaults
    next_state = state;
    next_position_counter = position_counter;
    next_prev_value = prev_value;
    next_total_changes = total_changes;
    next_current_input = current_input;
    next_current_output = current_output;
    next_result_changes = result_changes;
    next_candidate = candidate;
    next_best_candidate = best_candidate;
    next_best_changes = best_changes;

    case (state)
        IDLE: begin
            if (start) begin
                next_state = LOAD;
                next_position_counter = 3'b0;
                next_prev_value = 10'b0;
                next_total_changes = 8'b0;
                next_current_output = 10'b0;
            end
        end

        LOAD: begin
            if (load) begin
                next_current_input = current_number;
                next_state = COMPUTE;
                // Initialize computation variables
                if (position_counter == 3'b0) begin
                    // First number: keep as-is
                    next_current_output = current_number;
                    next_result_changes = 8'b0;
                    next_candidate = current_number;
                    next_best_candidate = current_number;
                    next_best_changes = 8'b0;
                    next_state = OUTPUT; // Skip compute for first number
                end else begin
                    // Subsequent numbers: start brute force from prev_value
                    next_candidate = prev_value;
                    next_best_candidate = prev_value;
                    next_best_changes = digit_changes(current_number, prev_value);
                    next_state = COMPUTE;
                end
            end
        end

        COMPUTE: begin
            // Try candidate, then increment
            if (candidate <= 999) begin
                // Check current candidate
                if (candidate >= prev_value) begin
                    if (candidate == prev_value) begin
                        // First iteration, already initialized
                        next_candidate = candidate + 1'b1;
                    end else begin
                        // Compare with current best
                        if (candidate <= 999) begin
                            reg [7:0] ch;
                            ch = digit_changes(current_input, candidate);
                            if (ch < best_changes) begin
                                next_best_changes = ch;
                                next_best_candidate = candidate;
                            end
                        end
                        next_candidate = candidate + 1'b1;
                    end
                end else begin
                    // Skip until candidate >= prev_value
                    next_candidate = prev_value;
                end
            end else begin
                // Done searching, move to OUTPUT
                next_current_output = best_candidate;
                next_result_changes = best_changes;
                next_state = OUTPUT;
            end
        end

        OUTPUT: begin
            // Update accumulators
            next_total_changes = total_changes + result_changes;
            next_prev_value = current_output;
            next_position_counter = position_counter + 1'b1;
            
            // Check if done
            if (position_counter >= n - 1'b1) begin
                next_state = DONE;
            end else begin
                next_state = LOAD;
            end
        end

        DONE: begin
            // Stay in DONE until reset or start
            if (!start) begin
                next_state = IDLE;
                next_done = 1'b0;
            end
        end

        default: next_state = IDLE;
    endcase
end

endmodule
