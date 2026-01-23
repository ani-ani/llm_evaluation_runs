module bracket_fix_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg signed [3:0] balance;
    reg signed [3:0] next_balance;
    reg signed [3:0] min_balance;
    reg signed [3:0] next_min_balance;
    reg [2:0] count;
    reg [2:0] next_count;
    reg next_result;
    reg next_done;

    // State transition and output logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            balance <= 4'sd0;
            min_balance <= 4'sd0;
            count <= 3'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            balance <= next_balance;
            min_balance <= next_min_balance;
            count <= next_count;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next state logic (Combinational)
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_balance = balance;
        next_min_balance = min_balance;
        next_count = count;
        next_result = result;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_result = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    next_balance = 4'sd0;
                    next_min_balance = 4'sd0;
                    next_count = 3'b0;
                end
            end

            PROCESSING: begin
                if (valid_in) begin
                    // Increment count for every valid character
                    next_count = count + 1'b1;

                    // Update balance based on char_in
                    if (char_in == 8'h28) begin // '('
                        next_balance = balance + 4'sd1;
                        // min_balance does not increase, keep current value
                        next_min_balance = min_balance;
                    end else if (char_in == 8'h29) begin // ')'
                        next_balance = balance - 4'sd1;
                        // Check if new balance is a new minimum
                        if (balance - 4'sd1 < min_balance)
                            next_min_balance = balance - 4'sd1;
                        else
                            next_min_balance = min_balance;
                    end else begin
                        // If unknown char, keep values (robustness)
                        next_balance = balance;
                        next_min_balance = min_balance;
                    end

                    // Check if 8 characters processed (count goes 0->1->...->7->8)
                    if (count == 3'b111) begin
                        next_state = DONE;
                        
                        // Final evaluation logic
                        // If final balance is 0 AND minimum balance was >= -1
                        if ((balance == 4'sd0 || (char_in == 8'h28 && balance + 4'sd1 == 4'sd0) || (char_in == 8'h29 && balance - 4'sd1 == 4'sd0)) && 
                            (min_balance >= 4'sd0)) begin
                             // Wait, I need to check the FINAL balance value in the next state calculation logic
                             // The balance variable currently holds the value BEFORE this cycle's update if we use non-blocking in seq block?
                             // No, I'm doing combinational next logic. The 'balance' input is the OLD value.
                             // Let's compute the prospective final balance.
                             
                             // Actually, the prompt says: "After processing 8 characters".
                             // If count is 3'b111, we are processing the 8th char (index 7).
                             // The result depends on the balance AFTER this char.
                             
                             // Let's use next_balance which holds the value AFTER this step.
                             // And next_min_balance.
                             
                             // To be safe, let's put the logic here:
                             
                             reg signed [3:0] final_balance;
                             reg signed [3:0] final_min;
                             
                             // Calculate tentative values
                             if (char_in == 8'h28) begin
                                final_balance = balance + 4'sd1;
                                final_min = min_balance;
                             end else begin // ')' (assumed)
                                final_balance = balance - 4'sd1;
                                final_min = (balance - 4'sd1 < min_balance) ? balance - 4'sd1 : min_balance;
                             end
                             
                             if (final_balance == 4'sd0 && final_min >= 4'sd0) // Wait, requirement is min >= -1
                                next_result = 1'b1;
                             else
                                next_result = 1'b0;
                             
                             // Correction on min >= -1 requirement
                             // Wait, let's re-read: "result = 1 if (balance == 0) AND (min_balance >= -1)"
                             // So final_min >= -4'sd1.
                             
                             if (final_balance == 4'sd0 && final_min >= -4'sd1)
                                next_result = 1'b1;
                             else
                                next_result = 1'b0;
                                 
                        end else begin
                             // Re-evaluating logic carefully inside the combinational block without nested always creates complexity.
                             // Let's move the specific evaluation logic here explicitly for the DONE transition.
                        end
                        
                        // Explicit Logic for Result at End of Processing
                        // Calculate potential final values
                        reg signed [3:0] calc_bal;
                        reg signed [3:0] calc_min;
                        
                        if (char_in == 8'h28) begin
                            calc_bal = balance + 4'sd1;
                            calc_min = min_balance;
                        end else begin
                            calc_bal = balance - 4'sd1;
                            calc_min = (balance - 4'sd1 < min_balance) ? balance - 4'sd1 : min_balance;
                        end
                        
                        if (calc_bal == 4'sd0 && calc_min >= -4'sd1)
                            next_result = 1'b1;
                        else
                            next_result = 1'b0;
                            
                        next_done = 1'b1;
                    end else begin
                        // Still processing, stay in PROCESSING
                        next_state = PROCESSING;
                        next_done = 1'b0;
                    end
                end else begin
                    // Wait for valid_in while in PROCESSING
                    next_state = PROCESSING;
                    next_count = count;
                    next_balance = balance;
                    next_min_balance = min_balance;
                end
            end

            DONE: begin
                // Stay in DONE until reset
                next_state = DONE;
                next_done = 1'b1;
                next_result = result; // Keep latched result
                next_balance = balance;
                next_min_balance = min_balance;
                next_count = count;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule

module TopModule(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output result,
    output done
);
    bracket_fix_checker uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .char_in(char_in),
        .valid_in(valid_in),
        .result(result),
        .done(done)
    );
endmodule