module text_match_two_three (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_index,
    output reg match,
    output reg done
);

    // ASCII constants
    localparam CHAR_A = 8'h61;
    localparam CHAR_B = 8'h62;

    // State encoding
    localparam IDLE        = 3'b000;
    localparam SEARCH_A    = 3'b001;
    localparam FOUND_A1    = 3'b010;
    localparam FOUND_AB    = 3'b011;
    localparam FOUND_ABB   = 3'b100;
    localparam FOUND_ABBB  = 3'b101;
    localparam DONE        = 3'b110;

    reg [2:0] current_state, next_state;

    // State transition logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = SEARCH_A;
                else       next_state = IDLE;
            end

            SEARCH_A: begin
                if (char_in == CHAR_A) next_state = FOUND_A1;
                else                   next_state = SEARCH_A;
            end

            FOUND_A1: begin
                if (char_in == CHAR_B)       next_state = FOUND_AB;
                else if (char_in == CHAR_A)  next_state = FOUND_A1;
                else                         next_state = SEARCH_A;
            end

            FOUND_AB: begin
                if (char_in == CHAR_B)       next_state = FOUND_ABB;
                else if (char_in == CHAR_A)  next_state = FOUND_A1;
                else                         next_state = SEARCH_A;
            end

            FOUND_ABB: begin
                if (char_in == CHAR_B)       next_state = FOUND_ABBB;
                else if (char_in == CHAR_A)  next_state = FOUND_A1;
                else                         next_state = SEARCH_A;
            end

            FOUND_ABBB: begin
                if (char_in == CHAR_A)       next_state = FOUND_A1;
                else                         next_state = SEARCH_A;
            end

            DONE: begin
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            match <= 1'b0;
            done  <= 1'b0;
        end else begin
            current_state <= next_state;

            // Output logic
            // Match is set high when reaching FOUND_ABB or FOUND_ABBB and stays high
            if (current_state == IDLE || current_state == SEARCH_A) begin
                match <= 1'b0;
            end else if (next_state == FOUND_ABB || next_state == FOUND_ABBB) begin
                match <= 1'b1;
            end
            // Keep match high if already set, unless resetting (handled above)
            // We don't clear match in DONE state, it should remain high if pattern found.

            // Done logic: Assert after processing 8 chars (index 7) or if in DONE state
            // The problem states "Done should be asserted after processing all 8 characters".
            // Also says "DONE: stay DONE".
            // We assume the control logic stops processing when done is high or resets on start.
            // If we are in any state and index is 7 (last char), we transition to DONE.
            // However, the state transition table provided in prompt implies manual transitions.
            // To strictly follow the prompt requirement "Done asserted after processing all 8 chars",
            // we force DONE when index is 7, regardless of current state (except IDLE).
            
            if (start) begin
                done <= 1'b0;
            end else if (char_index == 3'b111 && (current_state != IDLE && current_state != DONE)) begin
                done <= 1'b1;
                current_state <= DONE; // Force DONE state on last cycle
            end else if (current_state == DONE) begin
                done <= 1'b1;
            end
        end
    end

endmodule
