module duplicate_finder #(
    parameter N = 8,
    parameter W = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N-1:0][W-1:0] array_in,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] i, j; // Indices for nested loops (N=8 fits in 4 bits)
    reg match_found;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            // Update result and done based on state transitions
            case (next_state)
                DONE: begin
                    done <= 1;
                    result <= match_found;
                end
                IDLE: begin
                    done <= 0;
                    result <= 0;
                end
                default: begin
                    done <= 0;
                    result <= 0;
                end
            endcase
        end
    end

    // Combinational Logic for index updates and match detection
    always @(*) begin
        // Default values
        match_found = 1'b0;
        
        // Check for match only if we are in PROCESSING state and indices are valid
        // Logic: if we are currently comparing array[i] vs array[j] and they are equal
        if (state == PROCESSING && i < N) begin
            if (array_in[i] == array_in[j]) begin
                match_found = 1'b1;
            end
        end
    end

    // Datapath Logic (Counter updates)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0;
            j <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Initialize for first comparison (i=1, j=0)
                    if (start) begin
                        i <= 1;
                        j <= 0;
                    end
                end
                PROCESSING: begin
                    // Increment indices for next cycle
                    // Only update if we haven't found a match and haven't finished the loop
                    // The actual transition decision happens in next_state logic, but indices update here for the *next* potential cycle
                    // However, standard sequential logic dictates we update indices regardless, unless we are transitioning out.
                    // To handle the "Find and Stop" requirement efficiently without extra flags, 
                    // we compute the next indices here. If state transitions to DONE, these values won't matter.
                    
                    if (i < N && !match_found) begin
                        if (j + 1 < i) begin
                            j <= j + 1;
                        end else begin
                            // Reset j, increment i
                            j <= 0;
                            i <= i + 1;
                        end
                    end
                end
                DONE: begin
                    // Keep values or reset (optional, keeping values is fine)
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
            end
            PROCESSING: begin
                // Priority 1: Match Found -> Transition to DONE
                if (match_found) begin
                    next_state = DONE;
                end
                // Priority 2: End of loops (i reaches N) -> Transition to DONE
                else if (i >= N) begin // i == N check (since i starts at 1, i < N is the loop condition)
                    next_state = DONE;
                end
                // Otherwise stay in PROCESSING
            end
            DONE: begin
                // Stay in DONE until reset
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule