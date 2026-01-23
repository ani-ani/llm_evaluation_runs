module search_frequency(
    input clk,
    input rst_n,
    input start,
    input [3:0] array_size,
    input [7:0][3:0] data,
    output reg [3:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b001;
    localparam COUNT = 3'b010;
    localparam FIND_MAX = 3'b100;

    // Registers for State Machine
    reg [2:0] current_state;
    reg [2:0] next_state;

    // Registers for Data Processing
    reg [3:0] freq_regs [15:0];       // Frequency counters for values 0-15
    reg [3:0] index_ptr;              // Pointer for array elements (0-7)
    reg [3:0] search_val;             // Current value being checked (15 downto 1)

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = COUNT;
                else
                    next_state = IDLE;
            end
            COUNT: begin
                // Count for 8 cycles (indices 0 to 7), checking valid range < array_size
                if (index_ptr < 8)
                    next_state = COUNT;
                else
                    next_state = FIND_MAX;
            end
            FIND_MAX: begin
                // Search from 15 down to 1, then go to DONE
                if (search_val > 1)
                    next_state = FIND_MAX;
                else
                    next_state = IDLE; // Stays in IDLE (done is generated combinational)
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic (Sequential)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all frequency counters to 0
            for (i = 0; i < 16; i = i + 1) begin
                freq_regs[i] <= 4'b0000;
            end
            index_ptr <= 4'd0;
            search_val <= 4'd15;
            result <= 4'b0000;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Reset frequency counters and pointers on start
                        for (i = 0; i < 16; i = i + 1) begin
                            freq_regs[i] <= 4'b0000;
                        end
                        index_ptr <= 4'd0;
                        search_val <= 4'd15;
                        result <= 4'b0000; // Default 0
                    end
                end

                COUNT: begin
                    // Increment counter for the current element if valid
                    if (index_ptr < 8 && index_ptr < array_size) begin
                        // Check if data is strictly 1-15 (valid input, though instructions say 0-15 range)
                        // We count everything, but 0 will be ignored in FIND_MAX phase naturally
                        freq_regs[data[index_ptr]] <= freq_regs[data[index_ptr]] + 1'b1;
                    end
                    index_ptr <= index_ptr + 1'b1;
                end

                FIND_MAX: begin
                    // Check if current search_val satisfies count >= value
                    // Only check values 1 to 15 (positive integers)
                    if (search_val > 0 && freq_regs[search_val] >= search_val) begin
                        result <= search_val;
                        // We found the max (since we search downward), force jump to done next cycle logic
                        // or simply hold. To exit, we update state or search_val to trigger exit.
                        // Since we are in sequential block, we can detect condition and set result.
                        // We need to continue decrementing search_val until 0 to be sure? 
                        // No, instructions: "Return first (largest) value that satisfies condition"
                        // If we find one, we are done. We will set result and handle done signal.
                        // To implement "Done", we can just set search_val to 0 to force next state exit logic or
                        // rely on the state machine transition logic defined above.
                        // The defined logic goes to IDLE when search_val becomes 1. 
                        // We need to capture the max. We will store it in result.
                        // Note: The logic should keep searching downwards until 1. 
                        // However, if we find a value, we want that to be the final result. 
                        // If we find a larger value later (impossible as we descend), we'd overwrite.
                        // So simple descent works. 
                    end else if (search_val == 4'd1) begin
                        // If we reached 1 and haven't found anything (or 1 was invalid), 
                        // result stays at 0 (or whatever it was). 
                        // Requirement says return 15 if none found.
                        if (result == 4'd0) 
                            result <= 4'd15;
                    end
                    
                    // Decrement search value
                    if (search_val > 1)
                        search_val <= search_val - 1'b1;
                    else
                        search_val <= 4'd0; // End of search
                end
            endcase
        end
    end

    // Output Logic (Combinational for 'done')
    always @(*) begin
        if (current_state == IDLE && !start) begin
            done = 1'b1;
        end else if (current_state == FIND_MAX && (search_val == 4'd0 || search_val == 4'd1)) begin
             // Transition to IDLE happens at next clock edge. 
             // 'Done' should be high when computation is complete.
             // Strictly based on state machine, computation finishes at end of FIND_MAX.
             // We can assert done high in the last cycle of FIND_MAX.
             done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule