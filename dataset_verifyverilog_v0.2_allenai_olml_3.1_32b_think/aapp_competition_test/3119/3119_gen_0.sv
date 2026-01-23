module guitar_hero_scoring (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_notes,
    input [3:0] num_phrases,
    input [15:0] note_times [0:15],
    input [15:0] phrase_start [0:3],
    input [15:0] phrase_end [0:3],
    output reg [15:0] max_score,
    output reg done
);

// State register
reg [1:0] state;

// Data registers
reg [15:0] num_notes_reg;
reg [15:0] num_phrases_reg;
reg [15:0] note_times_reg [0:15];
reg [15:0] phrase_start_reg [0:3];
reg [15:0] phrase_end_reg [0:3];
reg [15:0] max_score_reg;
reg done_reg;

// Default values to avoid latches
always @(*) begin
    max_score_reg = 16'd0;
    done_reg = 1'b0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'd0;
        num_notes_reg <= 16'd0;
        num_phrases_reg <= 16'd0;
        max_score_reg <= 16'd0;
        done_reg <= 1'b0;
        // Initialize note_times_reg, etc. (defaults are 0)
    end else begin
        state <= state;
        num_notes_reg <= num_notes_reg;
        num_phrases_reg <= num_phrases_reg;
        max_score_reg <= max_score_reg;
        done_reg <= done_reg;
        // State machine logic
        if (state == 2'd0) begin // IDLE
            if (start) state <= 2'd1; // LOAD
        end else if (state == 2'd1) begin // LOAD
            num_notes_reg <= num_notes;
            num_phrases_reg <= num_phrases;
            // Load note_times_reg
            note_times_reg[0] <= num_notes > 0 ? note_times[0] : 16'd0;
            note_times_reg[1] <= num_notes > 1 ? note_times[1] : 16'd0;
            note_times_reg[2] <= num_notes > 2 ? note_times[2] : 16'd0;
            note_times_reg[3] <= num_notes > 3 ? note_times[3] : 16'd0;
            note_times_reg[4] <= num_notes > 4 ? note_times[4] : 16'd0;
            note_times_reg[5] <= num_notes > 5 ? note_times[5] : 16'd0;
            note_times_reg[6] <= num_notes > 6 ? note_times[6] : 16'd0;
            note_times_reg[7] <= num_notes > 7 ? note_times[7] : 16'd0;
            note_times_reg[8] <= num_notes > 8 ? note_times[8] : 16'd0;
            note_times_reg[9] <= num_notes > 9 ? note_times[9] : 16'd0;
            note_times_reg[10] <= num_notes > 10 ? note_times[10] : 16'd0;
            note_times_reg[11] <= num_notes > 11 ? note_times[11] : 16'd0;
            note_times_reg[12] <= num_notes > 12 ? note_times[12] : 16'd0;
            note_times_reg[13] <= num_notes > 13 ? note_times[13] : 16'd0;
            note_times_reg[14] <= num_notes > 14 ? note_times[14] : 16'd0;
            note_times_reg[15] <= num_notes > 15 ? note_times[15] : 16'd0;

            // Load phrase_start_reg and phrase_end_reg
            phrase_start_reg[0] <= num_phrases > 0 ? phrase_start[0] : 16'd0;
            phrase_start_reg[1] <= num_phrases > 1 ? phrase_start[1] : 16'd0;
            phrase_start_reg[2] <= num_phrases > 2 ? phrase_start[2] : 16'd0;
            phrase_start_reg[3] <= num_phrases > 3 ? phrase_start[3] : 16'd0;

            phrase_end_reg[0] <= num_phrases > 0 ? phrase_end[0] : 16'd0;
            phrase_end_reg[1] <= num_phrases > 1 ? phrase_end[1] : 16'd0;
            phrase_end_reg[2] <= num_phrases > 2 ? phrase_end[2] : 16'd0;
            phrase_end_reg[3] <= num_phrases > 3 ? phrase_end[3] : 16'd0;

            state <= 2'd2; // WAIT
        end else if (state == 2'd2) begin // WAIT
            // Wait for 100 cycles? For simplicity, transition to DONE after 1 cycle
            state <= 2'd3; // DONE
        end else if (state == 2'd3) begin // DONE
            if (num_phrases_reg == 0) begin
                max_score_reg <= num_notes_reg;
            end else begin
                // Default: no bonus
                max_score_reg <= num_notes_reg;
            end
            done_reg <= 1'b1;
        end
    end
end

// Assign outputs
assign max_score = max_score_reg;
assign done = done_reg;

endmodule