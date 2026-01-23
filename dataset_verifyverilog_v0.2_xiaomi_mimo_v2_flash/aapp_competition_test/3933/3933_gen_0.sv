module weather_prediction (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] temp_in,
    input [6:0] n,
    output reg signed [15:0] prediction,
    output reg done,
    output reg valid
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam CHECK = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam DONE = 3'b100;

    // State Registers
    reg [2:0] current_state, next_state;

    // Data Registers
    reg signed [15:0] prev_temp;
    reg signed [15:0] last_temp;
    reg signed [15:0] diff;
    reg is_arithmetic;
    reg [6:0] count;

    // Control Signals
    reg load_start;
    reg processing_done;

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
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                // Stay in LOAD until all n values are received
                // Transition to CHECK happens when the last value is received (count == n-1)
                // Note: Logic inside LOAD will handle the processing of the last value
                if (count == n && n > 0)
                    next_state = CHECK;
                else
                    next_state = LOAD;
            end
            CHECK: begin
                // Verify conditions and transition to COMPUTE
                if (n == 1)
                    next_state = COMPUTE;
                else if (n == 2)
                    next_state = COMPUTE;
                else begin
                    // If loop finished (count reached n), go to COMPUTE
                    if (count == n)
                        next_state = COMPUTE;
                    else
                        next_state = CHECK; // Continue verifying
                end
            end
            COMPUTE: begin
                next_state = DONE;
            end
            DONE: begin
                // Stay in DONE until next start pulse or reset
                if (start)
                    next_state = LOAD;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset State
            prediction <= 16'sd0;
            done <= 1'b0;
            valid <= 1'b0;
            count <= 7'd0;
            is_arithmetic <= 1'b1; // Default true, flag turns false
            prev_temp <= 16'sd0;
            last_temp <= 16'sd0;
            diff <= 16'sd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    count <= 7'd0;
                    is_arithmetic <= 1'b1;
                end

                LOAD: begin
                    // Always consume input
                    if (start) begin
                        // First value of sequence
                        prev_temp <= temp_in;
                        last_temp <= temp_in;
                        count <= 3'd1; // 1 value stored
                        is_arithmetic <= 1'b1;
                    end else begin
                        // Subsequent values
                        if (count == 7'd1) begin
                            // Second value: Calculate diff
                            diff <= temp_in - prev_temp;
                            last_temp <= temp_in;
                            prev_temp <= temp_in; // Shift window: old becomes prev
                            count <= count + 1'b1;
                        end else if (count < n) begin
                            // Third to Nth value: Check diff or just store
                            if (is_arithmetic) begin
                                if (temp_in - prev_temp != diff)
                                    is_arithmetic <= 1'b0;
                            end
                            last_temp <= temp_in;
                            prev_temp <= last_temp; // Shift window
                            count <= count + 1'b1;
                        end
                    end
                end

                CHECK: begin
                    // This state is primarily for flow control in FSM
                    // Specific verification logic handled in LOAD for values 3..N
                    // Special Handling for N=1 and N=2 cases that might be missed in LOAD logic depending on timing
                    if (n == 1) begin
                        // No difference to check, so it is trivially arithmetic
                        is_arithmetic <= 1'b1; 
                        // Ensure prev_temp is set correctly (it's the only value)
                        // last_temp already holds the value from LOAD
                    end else if (n == 2) begin
                        // Only diff calculated, no further verification needed
                        is_arithmetic <= 1'b1; // Always arithmetic with 2 points
                    end
                end

                COMPUTE: begin
                    // Determine prediction based on flag
                    if (is_arithmetic && n > 1) begin
                        // If arithmetic, predict next value (last + diff)
                        // Note: For N=2, diff is valid. For N>2, diff is valid and checks passed.
                        prediction <= last_temp + diff;
                    end else begin
                        // If not arithmetic, predict same as last value
                        prediction <= last_temp;
                    end
                    // Also ensure valid flag for N=1 case where logic is trivial
                    if (n == 1) begin
                        prediction <= last_temp;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    // Clear counters/flags to be ready for next start
                    count <= 7'd0;
                    is_arithmetic <= 1'b1;
                end
            endcase
        end
    end

endmodule