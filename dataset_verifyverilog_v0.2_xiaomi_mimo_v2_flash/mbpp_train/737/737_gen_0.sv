module vowel_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CHECK_FIRST = 2'b01;
    localparam WAIT_END = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state;
    reg [1:0] next_state;
    reg first_is_vowel;

    // Combinational logic for vowel detection
    always @(*) begin
        first_is_vowel = (char_in == 8'h61) || (char_in == 8'h65) || (char_in == 8'h69) || 
                         (char_in == 8'h6F) || (char_in == 8'h75) || (char_in == 8'h41) || 
                         (char_in == 8'h45) || (char_in == 8'h49) || (char_in == 8'h4F) || 
                         (char_in == 8'h55);
    end

    // State transition logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start && char_valid)
                    next_state = CHECK_FIRST;
                else
                    next_state = IDLE;
            end
            CHECK_FIRST: begin
                // After checking the first char, go to WAIT_END
                // We assume the check happens in the same cycle char_valid is high
                next_state = DONE;
            end
            WAIT_END: begin
                // Wait for null byte (8'h00) or max length logic.
                // Since the prompt specifies a fixed width max of 8 chars, 
                // but the interface is streaming byte by byte, we monitor char_in.
                // If we see a null, we are done. Otherwise, we need a counter or assumed length.
                // The prompt asks to wait for termination (null or max length).
                // Given latency of 2 cycles (IDLE->CHECK_FIRST->DONE), and the requirement 
                // to wait for termination, the most robust interpretation is:
                // Wait for a termination signal. If null, done. If max count, done.
                // However, with strictly 2 cycle latency, we might skip WAIT_END if no count.
                // But the prompt lists WAIT_END as a state. 
                // If we strictly follow latency: IDLE (Start) -> CHECK_FIRST (Char1) -> DONE.
                // To reconcile, I will assume for this specific implementation,
                // we process the first char, then immediately transition to DONE to meet latency,
                // effectively skipping complex WAIT_END counting if not explicitly provided a counter.
                // But to be safe and match the state diagram provided:
                if (char_valid) begin
                    if (char_in == 8'h00) 
                        next_state = DONE;
                    else
                        next_state = DONE; // Strictly following 2-cycle latency implies we finish quickly
                end else begin
                    next_state = WAIT_END;
                end
            end
            DONE: begin
                // Stay in DONE until reset or new start
                if (start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                end
                CHECK_FIRST: begin
                    // Capture result here
                    result <= first_is_vowel;
                    // Done might be asserted next cycle depending on flow
                    // If we go WAIT_END -> DONE, done is low here.
                    // If we go direct to DONE, done goes high here.
                end
                WAIT_END: begin
                    // If we transition to DONE based on char_valid, we assert done.
                end
                DONE: begin
                    done <= 1'b1;
                    // Result retained
                end
            endcase

            // Optimization for 2-cycle latency:
            // If in CHECK_FIRST and we have char_valid, we can assert done next cycle.
            // Since state transitions happen at clock edge, let's handle the flow:
            if (current_state == CHECK_FIRST) begin
                done <= 1'b1; // Assert done in next state (which is effectively WAIT_END or DONE)
            end
            
            // Logic correction: 
            // Cycle 1 (Start): State moves to CHECK_FIRST (on valid char).
            // Cycle 2 (Check): State moves to DONE (or WAIT_END). 
            // To ensure 'done' goes high exactly in the 2nd cycle after start:
            if (next_state == DONE && current_state != DONE) begin
                done <= 1'b1;
            end
        end
    end
    
    // Re-implementation of output logic to strictly match 2-cycle latency
    // and correct state behavior.
    // Let's simplify: 
    // Cycle 0: IDLE, Start asserted, Char Valid.
    // Cycle 1: State = CHECK_FIRST. Result evaluated. 
    // Cycle 2: State = DONE. Done asserted.
    
    // Overriding the always block for cleaner implementation
    reg done_reg;
    reg result_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_reg <= 1'b0;
            result_reg <= 1'b0;
            current_state <= IDLE;
        end else begin
            // Default assignments
            done_reg <= 1'b0;
            current_state <= next_state;
            
            case (next_state)
                CHECK_FIRST: begin
                    // We are here because we saw start and valid char in IDLE
                    result_reg <= first_is_vowel;
                end
                DONE: begin
                    done_reg <= 1'b1;
                end
            endcase
        end
    end
    
    // Wire outputs
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end
    
    // Redefine next_state to be purely combinational based on current_state and inputs
    always @(*) begin
        case (current_state)
            IDLE: next_state = (start && char_valid) ? CHECK_FIRST : IDLE;
            CHECK_FIRST: next_state = DONE; // 2-cycle latency requirement
            DONE: next_state = start ? IDLE : DONE; // Wait for reset or new start
            default: next_state = IDLE;
        endcase
    end

endmodule
