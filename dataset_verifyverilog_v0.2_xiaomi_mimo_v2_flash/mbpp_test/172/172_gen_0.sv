module std_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg [7:0] count,
    output reg done,
    output reg error
);

    // FSM State encoding for the main controller
    localparam S_IDLE = 2'b00;
    localparam S_PROCESSING = 2'b01;
    localparam S_DONE = 2'b10;

    // Substring detection state encoding
    localparam SUB_IDLE = 2'b00;
    localparam SUB_S = 2'b01;
    localparam SUB_ST = 2'b10;

    // Main FSM registers
    reg [1:0] main_state;
    reg [1:0] next_main_state;

    // Processing registers
    reg [5:0] char_count; // Counts processed chars (0-32)
    reg [1:0] sub_state;  // Tracks 'std' progress
    reg [7:0] count_reg;  // Accumulator for occurrences
    reg error_reg;
    reg done_reg;

    // Control signals logic
    wire max_len_reached;
    wire is_null;
    wire is_s;
    wire is_t;
    wire is_d;

    // Helper signals
    assign is_null = (char_in == 8'h00);
    assign is_s = (char_in == 8'h73); // 's'
    assign is_t = (char_in == 8'h74); // 't'
    assign is_d = (char_in == 8'h64); // 'd'
    assign max_len_reached = (char_count == 6'd32);

    // Main State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            main_state <= S_IDLE;
        end else begin
            main_state <= next_main_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_main_state = main_state; // Default hold state

        case (main_state)
            S_IDLE: begin
                if (start) begin
                    next_main_state = S_PROCESSING;
                end
            end

            S_PROCESSING: begin
                if (valid_in) begin
                    if (is_null || max_len_reached || error_reg) begin
                        next_main_state = S_DONE;
                    end else begin
                        next_main_state = S_PROCESSING; // Still processing
                    end
                end else if (!start) begin
                    // Return to IDLE if start is deasserted (Behavioral Req 6)
                    next_main_state = S_IDLE;
                end
            end

            S_DONE: begin
                if (!start) begin
                    next_main_state = S_IDLE;
                end
            end

            default: next_main_state = S_IDLE;
        endcase
    end

    // Datapath Logic (Processing Registers)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_count <= 6'd0;
            sub_state <= SUB_IDLE;
            count_reg <= 8'd0;
            error_reg <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            case (main_state)
                S_IDLE: begin
                    // Reset processing logic when in IDLE or when transitioning to PROCESSING
                    // Handled below in the transition check
                    if (next_main_state == S_PROCESSING) begin
                        char_count <= 6'd0;
                        sub_state <= SUB_IDLE;
                        count_reg <= 8'd0;
                        error_reg <= 1'b0;
                        done_reg <= 1'b0;
                    end
                end

                S_PROCESSING: begin
                    if (valid_in) begin
                        // Increment character counter for every valid input
                        char_count <= char_count + 1'b1;

                        // Check for overflow error (req: error if >32 chars)
                        // If we are at 32 and receive another valid char that isn't null, it's error
                        if (char_count >= 6'd32 && !is_null) begin
                            error_reg <= 1'b1;
                            // Logic: Keep counting strictly for detection of termination conditions
                        end

                        // Substring FSM Logic
                        case (sub_state)
                            SUB_IDLE: begin
                                if (is_s) sub_state <= SUB_S;
                                else if (is_null) begin // Terminate on null in idle
                                    // No change to state, but DONE will be triggered
                                end
                                else begin
                                    sub_state <= SUB_IDLE; // Stay in 0
                                end
                            end

                            SUB_S: begin
                                if (is_t) sub_state <= SUB_ST;
                                else if (is_s) sub_state <= SUB_S; // New 's' starts potential match
                                else if (is_null) sub_state <= SUB_IDLE; // Reset on null
                                else sub_state <= SUB_IDLE; // Wrong char, reset
                            end

                            SUB_ST: begin
                                if (is_d) begin
                                    count_reg <= count_reg + 1'b1; // Increment count
                                    sub_state <= SUB_IDLE;         // Reset sequence
                                end else if (is_s) begin
                                    sub_state <= SUB_S; // New start
                                end else if (is_t) begin
                                    // 't' in state 2 is wrong char, but wait... 
                                    // "Any wrong character resets FSM to state 0" per spec.
                                    // However, 't' doesn't start a match, so it goes to 0.
                                    sub_state <= SUB_IDLE;
                                end else begin
                                    sub_state <= SUB_IDLE;
                                end
                            end
                        endcase
                    end
                end

                S_DONE: begin
                    // Latch done high in this state
                    done_reg <= 1'b1;
                end
            endcase
        end
    end

    // Output Assignments
    // Output 'done' is high in DONE state or if valid null/length reached logic triggered
    // The behavioral spec says "done goes high when string terminates...".
    // Our logic latches done_reg in S_DONE. 
    // We must ensure done goes high even if we are in S_PROCESSING but hit the termination condition (null/32).
    // The spec implies done goes high *when* it happens.
    // Refinement: Let's drive done output based on the state transition or current state.

    // To strictly follow "done goes high when...", we can output done high 
    // if we are in DONE state OR if we are processing the final terminating character.
    // However, standard practice is to hold done high.

    // Let's make outputs combinational based on registers, or just assign the registers.
    // The spec says "Return to IDLE when start is deasserted".
    // If we are in S_DONE and start stays high, done stays high.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            // Update outputs mainly when in processing or done
            if (main_state == S_IDLE && next_main_state == S_PROCESSING) begin
                // Clear outputs at start of transaction
                done <= 1'b0;
                error <= 1'b0;
                count <= 8'd0;
            end else begin
                count <= count_reg;
                error <= error_reg;

                // Done logic: 
                // 1. We are in DONE state.
                // 2. OR we are in PROCESSING, valid_in is high, and it's a terminator/error condition.
                // However, registers update on clock edge. The termination condition causes transition to DONE next cycle.
                // So in S_DONE, done_reg is high. 
                if (main_state == S_DONE || 
                   (main_state == S_PROCESSING && valid_in && (is_null || max_len_reached || (char_count >= 6'd32 && !is_null && error_reg)))) begin
                    done <= 1'b1;
                end else if (main_state == S_IDLE) begin
                    done <= 1'b0;
                end
            end
        end
    end

endmodule