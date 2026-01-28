module rhythm_game_max_score(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] notes [0:15],
    input wire [3:0] num_notes,
    input wire [15:0] phrases_start [0:15],
    input wire [15:0] phrases_end [0:15],
    input wire [3:0] num_phrases,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_BASE = 4'd1;
    localparam [3:0] COMPUTE_PHRASES = 4'd2;
    localparam [3:0] FINISH = 4'd3;

    reg [3:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // Internal registers
    reg [23:0] base_score;
    reg [23:0] max_score;
    reg [23:0] current_score;
    reg [15:0] phrase_idx;
    reg [15:0] note_idx;
    reg [15:0] best_activation_time;
    reg [15:0] current_activation_time;
    reg [15:0] doubled_notes;
    reg [15:0] temp_doubled;
    reg [15:0] phrase_start_time;
    reg [15:0] phrase_end_time;
    reg [15:0] note_time;
    reg [15:0] sp_duration;
    reg [15:0] sp_start;
    reg [15:0] sp_end;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            base_score <= 24'd0;
            max_score <= 24'd0;
            current_score <= 24'd0;
            phrase_idx <= 16'd0;
            note_idx <= 16'd0;
            best_activation_time <= 16'd0;
            current_activation_time <= 16'd0;
            doubled_notes <= 16'd0;
            temp_doubled <= 16'd0;
            phrase_start_time <= 16'd0;
            phrase_end_time <= 16'd0;
            note_time <= 16'd0;
            sp_duration <= 16'd0;
            sp_start <= 16'd0;
            sp_end <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= COMPUTE_BASE;
                    end
                end

                COMPUTE_BASE: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Compute base score (sum of all notes)
                        base_score <= 24'd0;
                        for (note_idx = 0; note_idx < num_notes; note_idx = note_idx + 1'b1) begin
                            base_score <= base_score + notes[note_idx];
                        end
                        max_score <= base_score;
                        phrase_idx <= 16'd0;
                        state <= COMPUTE_PHRASES;
                    end
                end

                COMPUTE_PHRASES: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else if (phrase_idx >= num_phrases) begin
                        state <= FINISH;
                    end else begin
                        // Get current phrase times
                        phrase_start_time <= phrases_start[phrase_idx];
                        phrase_end_time <= phrases_end[phrase_idx];
                        sp_duration <= phrase_end_time - phrase_start_time;

                        // Find best activation time for this phrase
                        best_activation_time <= 16'd0;
                        doubled_notes <= 16'd0;

                        // Try activating SP at phrase start
                        current_activation_time <= phrase_start_time;
                        sp_start <= current_activation_time;
                        sp_end <= sp_start + sp_duration;
                        temp_doubled <= 16'd0;

                        // Count notes that fall within SP window
                        for (note_idx = 0; note_idx < num_notes; note_idx = note_idx + 1'b1) begin
                            note_time <= notes[note_idx];
                            if (note_time >= sp_start && note_time < sp_end) begin
                                temp_doubled <= temp_doubled + 1'b1;
                            end
                        end

                        // Update best if this is better
                        if (temp_doubled > doubled_notes) begin
                            doubled_notes <= temp_doubled;
                            best_activation_time <= current_activation_time;
                        end

                        // Add doubled notes to score
                        current_score <= base_score + (doubled_notes * 24'd1);
                        if (current_score > max_score) begin
                            max_score <= current_score;
                        end

                        // Move to next phrase
                        phrase_idx <= phrase_idx + 1'b1;
                    end
                end

                FINISH: begin
                    result <= max_score;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 24'd0;
                end
            endcase
        end
    end
endmodule