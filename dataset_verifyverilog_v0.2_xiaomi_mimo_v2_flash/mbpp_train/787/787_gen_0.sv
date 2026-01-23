module pattern_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg match,
    output reg done
);

    // State encoding
    localparam IDLE = 4'b0000;
    localparam S_A = 4'b0001;
    localparam S_B1 = 4'b0010;
    localparam S_B2 = 4'b0011;
    localparam S_B3 = 4'b0100;
    localparam MATCH = 4'b0101;
    localparam DONE = 4'b0110;

    reg [3:0] current_state, next_state;
    reg [3:0] cnt, next_cnt;

    // ASCII constants
    localparam CHAR_A = 8'h61;
    localparam CHAR_B = 8'h62;

    // Combinational Next State Logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_cnt = cnt;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = S_A;
                    next_cnt = 4'b0000;
                end
            end

            S_A: begin
                if (start) begin
                    next_state = IDLE;
                end else if (valid_in) begin
                    if (char_in == CHAR_A) begin
                        next_state = S_B1;
                    end
                    // If not 'a', stay in S_A (looking for 'a')
                    
                    // Counter increment logic
                    if (cnt == 4'd15) begin
                        next_state = DONE;
                        next_cnt = 4'b0000; // Reset counter for DONE state cycle
                    end else begin
                        next_cnt = cnt + 1'b1;
                    end
                end
            end

            S_B1: begin
                if (start) begin
                    next_state = IDLE;
                end else if (valid_in) begin
                    if (char_in == CHAR_B) begin
                        next_state = S_B2;
                    end else if (char_in == CHAR_A) begin
                        next_state = S_B1; // Restart pattern search (stay looking for 'a', but effectively same state)
                    end else begin
                        next_state = S_A; // Reset to looking for 'a'
                    end

                    if (cnt == 4'd15) begin
                        next_state = DONE;
                        next_cnt = 4'b0000;
                    end else begin
                        next_cnt = cnt + 1'b1;
                    end
                end
            end

            S_B2: begin
                if (start) begin
                    next_state = IDLE;
                end else if (valid_in) begin
                    if (char_in == CHAR_B) begin
                        next_state = S_B3;
                    end else if (char_in == CHAR_A) begin
                        next_state = S_B1;
                    end else begin
                        next_state = S_A;
                    end

                    if (cnt == 4'd15) begin
                        next_state = DONE;
                        next_cnt = 4'b0000;
                    end else begin
                        next_cnt = cnt + 1'b1;
                    end
                end
            end

            S_B3: begin
                if (start) begin
                    next_state = IDLE;
                end else if (valid_in) begin
                    if (char_in == CHAR_B) begin
                        next_state = MATCH;
                    end else if (char_in == CHAR_A) begin
                        next_state = S_B1;
                    end else begin
                        next_state = S_A;
                    end

                    if (cnt == 4'd15) begin
                        next_state = DONE;
                        next_cnt = 4'b0000;
                    end else begin
                        next_cnt = cnt + 1'b1;
                    end
                end
            end

            MATCH: begin
                // Stay in MATCH until reset or start
                if (start) begin
                    next_state = IDLE;
                end
                // We do not count characters in MATCH state per requirements
            end

            DONE: begin
                // Stay in DONE until reset or start
                if (start) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
                next_cnt = 4'b0000;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            cnt <= 4'b0000;
            match <= 1'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            cnt <= next_cnt;
            
            // Output registration
            match <= (next_state == MATCH);
            done <= (next_state == DONE);
        end
    end

endmodule
