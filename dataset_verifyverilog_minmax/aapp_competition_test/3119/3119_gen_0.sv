module guitar_hero_scorer (
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [3:0] n_notes,
    input reg [1:0] p_phrases,
    input reg [15:0] notes [15:0],
    input reg [15:0] sp_starts [3:0],
    input reg [15:0] sp_ends [3:0],
    output reg [7:0] max_score,
    output reg done
);

    // Internal registers
    reg [3:0] n_notes_r;
    reg [1:0] p_phrases_r;
    reg [15:0] notes_r [15:0];
    reg [15:0] sp_starts_r [3:0];
    reg [15:0] sp_ends_r [3:0];
    reg [4:0] combo;
    reg [4:0] combo_limit;
    reg [7:0] best_score;
    reg [7:0] curr_score;
    reg [15:0] note_mask [0:3];

    // SP mask for current combination
    wire [15:0] sp_mask;
    assign sp_mask = (combo[0] ? note_mask[0] : 16'b0) |
                     (combo[1] ? note_mask[1] : 16'b0) |
                     (combo[2] ? note_mask[2] : 16'b0) |
                     (combo[3] ? note_mask[3] : 16'b0);

    // Popcount for 4-bit nibble
    function [2:0] pop4;
        input [3:0] nib;
        case (nib)
            4'b0000: pop4 = 3'd0;
            4'b0001: pop4 = 3'd1;
            4'b0010: pop4 = 3'd1;
            4'b0011: pop4 = 3'd2;
            4'b0100: pop4 = 3'd1;
            4'b0101: pop4 = 3'd2;
            4'b0110: pop4 = 3'd2;
            4'b0111: pop4 = 3'd3;
            4'b1000: pop4 = 3'd1;
            4'b1001: pop4 = 3'd2;
            4'b1010: pop4 = 3'd2;
            4'b1011: pop4 = 3'd3;
            4'b1100: pop4 = 3'd2;
            4'b1101: pop4 = 3'd3;
            4'b1110: pop4 = 3'd3;
            4'b1111: pop4 = 3'd4;
        endcase
    endfunction

    // Popcount for the SP mask
    wire [2:0] pop0, pop1, pop2, pop3;
    assign pop0 = pop4(sp_mask[3:0]);
    assign pop1 = pop4(sp_mask[7:4]);
    assign pop2 = pop4(sp_mask[11:8]);
    assign pop3 = pop4(sp_mask[15:12]);
    wire [5:0] total_sp_notes = {3'b0, pop0} + {3'b0, pop1} + {3'b0, pop2} + {3'b0, pop3};

    // Current score for this combination
    always @(*) curr_score = n_notes_r + total_sp_notes;

    // Compute which notes fall inside each phrase interval
    always @(*) begin
        // Initialize masks
        for (int i=0; i<4; i++) note_mask[i] = 16'b0;
        for (int i=0; i<4; i++) begin
            if (i < p_phrases_r) begin
                for (int j=0; j<16; j++) begin
                    if (j < n_notes_r) begin
                        if (notes_r[j] >= sp_starts_r[i] && notes_r[j] <= sp_ends_r[i]) note_mask[i][j] = 1;
                    end
                end
            end
        end
    end

    // FSM for processing all activation combinations
    parameter IDLE = 1'b0;
    parameter CALC = 1'b1;
    reg state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_score <= 8'b0;
            done <= 1'b0;
            best_score <= 8'b0;
            combo <= 5'b0;
            combo_limit <= 5'b0;
            n_notes_r <= 4'b0;
            p_phrases_r <= 2'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_notes_r <= n_notes;
                        p_phrases_r <= p_phrases;
                        notes_r <= notes;
                        sp_starts_r <= sp_starts;
                        sp_ends_r <= sp_ends;
                        combo_limit <= (1 << p_phrases_r);
                        combo <= 5'b0;
                        best_score <= 8'b0;
                        state <= CALC;
                    end
                end
                CALC: begin
                    // Update best score for the current combination
                    if (curr_score > best_score) best_score <= curr_score;
                    // If this was the last combination, finish after this cycle
                    if (combo + 1 == combo_limit) begin
                        max_score <= best_score;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                    // Move to next combination (or stay if finished)
                    combo <= combo + 1;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule