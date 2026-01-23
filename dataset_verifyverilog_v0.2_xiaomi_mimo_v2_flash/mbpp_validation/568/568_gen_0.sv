module empty_list (
    input clk,
    input rst_n,
    input start,
    input [7:0] length,
    output reg [63:0] result_array,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam FILL = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [5:0] count; // Counter for number of items to fill
    reg [5:0] safe_len; // Capped length

    // Sequential Logic: State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Combinational Logic: Next State & Output Logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        done = 1'b0;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = FILL;
                end else begin
                    next_state = IDLE;
                end
            end
            
            FILL: begin
                // Latency requirement: 3 cycles total.
                // Cycle 1: Start triggers FILL state entry (and reset logic in sequential block).
                // Cycle 2: FILL state active (processing/clearing logic). 
                // Cycle 3: Transition to DONE.
                next_state = DONE;
            end
            
            DONE: begin
                done = 1'b1;
                // Stay in DONE until reset or new start
                if (start) begin
                    next_state = FILL;
                end else begin
                    next_state = DONE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic: Data Processing
    // Latency requirement: Result valid 3 clock cycles after start.
    // To meet this strictly:
    // 1. Start rising edge -> State transitions to FILL at next clock.
    // 2. Inside FILL state (Cycle 1 of processing) -> Result updated.
    // 3. Next clock -> State transitions to DONE (Cycle 2 of processing), done asserted.
    // Result is valid when done is asserted. This satisfies 3 cycles (Start->FILL->DONE).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_array <= 64'h0;
            safe_len <= 6'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Immediately capture and cap length on start
                        if (length > 64) safe_len <= 64; 
                        else safe_len <= length[5:0];
                    end
                end
                
                FILL: begin
                    // In hardware, 'empty dictionary' is 0. 
                    // The requirements say 'clear the entire 64-bit result to 0'.
                    // However, test cases imply we only care about the first N bits.
                    // Logic: Clear all bits, or just the relevant N bits?
                    // Requirement 4: "clear the entire 64-bit result to 0".
                    // Result Array is cleared to 0.
                    result_array <= 64'h0;
                end
                
                DONE: begin
                    // Maintain state unless reset
                    result_array <= result_array;
                end
                
                default: begin
                    result_array <= 64'h0;
                end
            endcase
        end
    end

endmodule
