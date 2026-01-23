module unique_tuples (
    input clk,
    input rst_n, // active low
    input start,
    input [7:0] tuple_data [0:3][0:1], // 4 tuples, each with two 8-bit elements
    output reg [3:0] result,
    output reg done
);

// Registers
reg [1:0] state; // 2 bits: IDLE=00, LOAD=01, COMPARE=10, COUNT=11
reg [1:0] tuple_idx;
reg [7:0] current_tuple_element0, current_tuple_element1;
reg [7:0] stored_tuples [3][2]; // 4 entries, each with two 8-bit elements
reg [2:0] unique_count;
reg [1:0] prev_state; // to detect transitions from IDLE to LOAD

// Combinational logic for is_unique
wire is_unique;
assign is_unique = 1'b1;
if (unique_count > 0) begin
    if ( (stored_tuples[0][0] == current_tuple_element0) && (stored_tuples[0][1] == current_tuple_element1) )
        is_unique = 1'b0;
end
if (unique_count > 1) begin
    if ( (stored_tuples[1][0] == current_tuple_element0) && (stored_tuples[1][1] == current_tuple_element1) )
        is_unique = 1'b0;
end
if (unique_count > 2) begin
    if ( (stored_tuples[2][0] == current_tuple_element0) && (stored_tuples[2][1] == current_tuple_element1) )
        is_unique = 1'b0;
end
if (unique_count > 3) begin // i.e., >=4
    if ( (stored_tuples[3][0] == current_tuple_element0) && (stored_tuples[3][1] == current_tuple_element1) )
        is_unique = 1'b0;
end

// Output assignments
assign result = unique_count;
assign done = (tuple_idx == 3) && (state == 2'b00);

// State transition and register update logic
always @(posedge clk) begin
    if (!rst_n) begin
        // Reset all registers
        state <= 2'b00;
        tuple_idx <= 2'b00;
        current_tuple_element0 <= 8'b0;
        current_tuple_element1 <= 8'b0;
        unique_count <= 3'b000;
        stored_tuples[0] <=8'b0;
        stored_tuples[1] <=8'b0;
        stored_tuples[2] <=8'b0;
        stored_tuples[3] <=8'b0;
        prev_state <= 2'b00;
    end else begin
        prev_state <= state; // update previous state for transition detection

        // Reset stored_tuples when starting new computation (LOAD with tuple_idx=0 and unique_count=0)
        if (state == 2'b01) begin // LOAD state
            if (tuple_idx == 2'b00 && unique_count ==3'b000) begin
                stored_tuples[0] <=8'b0;
                stored_tuples[1] <=8'b0;
                stored_tuples[2] <=8'b0;
                stored_tuples[3] <=8'b0;
            end
        end

        case ({state, prev_state})
            // Transition from IDLE to LOAD when start is high
            2'b00, 2'b00: begin
                if (start == 1'b1) begin
                    state <= 2'b01; // LOAD
                    tuple_idx <= 2'b00;
                    unique_count <= 3'b000;
                end else begin
                    state <= 2'b00; // stay in IDLE
                end
            end
            // In LOAD state: capture current tuple
            2'b01, 2'bXX: begin
                // Load the current tuple_data[tuple_idx][0] and [1]
                current_tuple_element0 <= tuple_data[tuple_idx][0];
                current_tuple_element1 <= tuple_data[tuple_idx][1];
                // Move to COMPARE state next
                state <= 2'b10; // COMPARE
            end
            // In COMPARE state: do nothing but transition to COUNT
            2'b10, 2'bXX: begin
                state <= 2'b11; // COUNT
            end
            // In COUNT state: process uniqueness and move to next
            2'b11, 2'bXX: begin
                if (is_unique) begin
                    // Store the tuple if unique
                    stored_tuples[unique_count][0] <= current_tuple_element0;
                    stored_tuples[unique_count][1] <= current_tuple_element1;
                    unique_count <= unique_count + 1;
                end
                // Move to next state: if more tuples, go to LOAD, else DONE (IDLE)
                if (tuple_idx < 2'b11) begin // tuple_idx < 3?
                    state <= 2'b01; // LOAD for next tuple
                    tuple_idx <= tuple_idx + 1;
                end else begin
                    state <= 2'b00; // IDLE, computation done
                end
            end
            // Default: stay in current state
            default: state <= state;
        endcase
    end
end

endmodule