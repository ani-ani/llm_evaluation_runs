module text_match_two_three (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] char_in,
    input [2:0] char_index,
    output reg match,
    output reg done
);

localparam IDLE = 3'd0,
SEARCH_A = 3'd1,
FOUND_A1 = 3'd2,
FOUND_AB = 3'd3,
FOUND_ABB = 3'd4,
FOUND_ABBB = 3'd5,
DONE = 3'd6;

reg [2:0] state;

// FSM and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        match <= 0;
        done <= 0;
    end else begin
        // Compute normal next state
        reg [2:0] normal_next_state;
        normal_next_state = state;

        // Current state transitions for normal_next_state
        if (state == IDLE) begin
            if (start == 1) begin
                normal_next_state = SEARCH_A;
            end
        end else if (state == SEARCH_A) begin
            if (char_in == 8'h61) begin // 'a'
                normal_next_state = FOUND_A1;
            end
        end else if (state == FOUND_A1) begin
            if (char_in == 8'h62) begin // 'b'
                normal_next_state = FOUND_AB;
            end else if (char_in == 8'h61) begin
                normal_next_state = FOUND_A1;
            end else begin
                normal_next_state = SEARCH_A;
            end
        end else if (state == FOUND_AB) begin
            if (char_in == 8'h62) begin
                normal_next_state = FOUND_ABB;
            end else if (char_in == 8'h61) begin
                normal_next_state = FOUND_A1;
            end else begin
                normal_next_state = SEARCH_A;
            end
        end else if (state == FOUND_ABB) begin
            if (char_in == 8'h62) begin
                normal_next_state = FOUND_ABBB;
            end else if (char_in == 8'h61) begin
                normal_next_state = FOUND_A1;
            end else begin
                normal_next_state = SEARCH_A;
            end
        end else if (state == FOUND_ABBB) begin
            if (char_in == 8'h61) begin
                normal_next_state = FOUND_A1;
            end else begin
                normal_next_state = SEARCH_A;
            end
        end

        // Update match based on normal_next_state
        if (normal_next_state == FOUND_ABB || normal_next_state == FOUND_ABBB) begin
            match <= 1;
        end else begin
            match <= match;
        end

        // Determine final next_state: transition to DONE if last character
        reg [2:0] next_state;
        if (char_index == 3'd7) begin
            next_state = DONE;
        end else begin
            next_state = normal_next_state;
        end

        // Update state and done
        state <= next_state;
        done <= (next_state == DONE) ? 1 : done;
    end
endmodule