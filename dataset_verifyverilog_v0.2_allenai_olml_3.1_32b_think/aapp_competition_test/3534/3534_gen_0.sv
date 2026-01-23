module mirka_optimizer (
    input clk,
    input rst_n,                 // active-low reset
    input start,
    input [3:0] num_notes,
    input [15:0] note_data,
    input note_valid,
    output reg [15:0] max_correct,
    output reg [31:0] best_k,
    output reg done
);

localparam IDLE = 3'd0,
        COLLECT = 3'd1,
        CANDIDATE = 3'd2,
        SIMULATE = 3'd3,
        DONE_STATE = 3'd4;

reg [2:0] state, next_state;
reg [15:0] notes [0:15];
reg [31:0] k_values [0:15];
reg [3:0] k_count;
reg [3:0] current_k_index;
reg [15:0] max_correct_reg, best_k_reg;
reg [31:0] current_k;
reg [3:0] buffer_index;
reg [15:0] prev_played;
reg done_reg;

assign max_correct = max_correct_reg;
assign best_k = best_k_reg;
assign done = done_reg;

always @(negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        buffer_index <= 4'd0;
        k_count <= 4'd0;
        current_k_index <=4'd0;
        max_correct_reg <=16'd0;
        best_k_reg <=32'd0;
        done_reg <=1'b0;
        for (int i=0; i<16; i++) begin
            notes[i] <=16'd0;
            k_values[i] <=32'd0;
        end
    end
end

always @(posedge clk) begin
    int i, j, delta, found, temp_count, note_i, prev_note, expected, played, correct;
    int temp_k_values [0:15];

    if (state == IDLE) begin
        if (start) begin
            next_state <= COLLECT;
            buffer_index <=4'd0;
            k_count <=4'd0;
            current_k_index <=4'd0;
            max_correct_reg <=16'd0;
            best_k_reg <=32'd0;
        end else begin
            next_state <= IDLE;
        end
    end else if (state == COLLECT) begin
        if (note_valid) begin
            notes[buffer_index] <= note_data;
            buffer_index <= buffer_index +1;
            if (buffer_index == num_notes) begin
                next_state <= CANDIDATE;
            end else begin
                next_state <= COLLECT;
            end
        end else begin
            next_state <= COLLECT;
        end
    end else if (state == CANDIDATE) begin
        // Generate K candidates
        temp_count =0;

        // Collect non-zero unique deltas
        for (i=0; i < num_notes-1; i++) begin
            delta = notes[i+1] - notes[i];
            if (delta <0) delta = -delta;
            if (delta ==0) continue;
            found =0;
            for (j=0; j<temp_count; j++) begin
                if (temp_k_values[j] == delta) begin
                    found =1;
                    break;
                end
            end
            if (!found) begin
                temp_k_values[temp_count] = delta;
                temp_count +=1;
            end
        end

        // Add K=0 if not present
        if (temp_count ==0) begin // all deltas were zero
            temp_k_values[temp_count] =0;
            temp_count +=1;
        end else begin
            found =0;
            for (j=0; j<temp_count; j++) begin
                if (temp_k_values[j] ==0) begin
                    found =1;
                    break;
                end
            end
            if (!found) begin
                temp_k_values[temp_count] =0;
                temp_count +=1;
            end
        end

        // Assign to registers
        k_count <= temp_count;
        for (i=0; i < temp_count; i++) begin
            k_values[i] <= temp_k_values[i];
        end
        next_state <= SIMULATE;
    end else if (state == SIMULATE) begin
        // Get current K
        current_k = k_values[current_k_index];
        // Simulate the sequence
        correct =1;
        played = notes[0];
        for (i=1; i < num_notes; i++) begin
            note_i = notes[i];
            prev_note = notes[i-1];
            if (note_i > prev_note) begin
                expected = played + current_k;
            end else if (note_i < prev_note) begin
                expected = played - current_k;
            end else begin
                expected = played;
            end
            if (expected == note_i) begin
                correct +=1;
            end
            played = expected;
        end
        // Update max and best_k if needed
        if (correct > max_correct_reg) begin
            max_correct_reg <= correct;
            best_k_reg <= current_k;
        end
        // Move to next K
        current_k_index <= current_k_index +1;
        if (current_k_index < k_count) begin
            next_state <= SIMULATE;
        end else begin
            next_state <= DONE_STATE;
            done_reg <=1'b1;
        end
    end else if (state == DONE_STATE) begin
        next_state <= DONE_STATE;
        done_reg <=1'b1;
    end else begin
        next_state <= IDLE;
    end

    // Update state
    state <= next_state;
endmodule