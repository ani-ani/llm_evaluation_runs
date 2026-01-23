module game_winner (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    output reg [1:0] result,
    output reg valid,
    output reg done
);

    // Parameters
    parameter MAX_LEN = 64;

    // States
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state, next_state;
    reg [7:0] min_char, next_min_char;
    reg [6:0] count, next_count; // Counts up to 64 (0-63)
    
    // Pipeline registers for latency requirement
    // Cycle 1: Input sampled, comparison done
    // Cycle 2: Result valid
    reg [1:0] result_pipe_1, next_result_pipe_1;
    reg valid_pipe_1, next_valid_pipe_1;
    
    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
            end
            PROCESSING: begin
                if (count == MAX_LEN - 1) 
                    next_state = DONE;
                else if (!start) // Assuming 'start' gating or external stop
                     next_state = DONE; // Handle implicit stop if start drops
            end
            DONE: begin
                // Remain in DONE until reset
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(*) begin
        // Default assignments to prevent latches
        next_min_char = min_char;
        next_count = count;
        next_result_pipe_1 = result_pipe_1;
        next_valid_pipe_1 = valid_pipe_1;

        case (state)
            IDLE: begin
                next_min_char = 8'h7F; // 127
                next_count = 0;
                next_valid_pipe_1 = 0;
                // result_pipe_1 defaults to previous or 0
            end
            PROCESSING: begin
                // Processing Logic for current char_in
                // Compare char_in with current min_char
                if (char_in > min_char) begin
                    next_result_pipe_1 = 2'b01; // Ann
                end else begin
                    next_result_pipe_1 = 2'b00; // Mike
                end
                
                next_valid_pipe_1 = 1'b1;
                
                // Update min_char
                if (char_in < min_char) begin
                    next_min_char = char_in;
                end else begin
                    next_min_char = min_char;
                end
                
                // Increment Counter
                if (count < MAX_LEN - 1) begin
                    next_count = count + 1;
                end else begin
                    next_count = count;
                end
            end
            DONE: begin
                next_valid_pipe_1 = 1'b0;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_char <= 8'h7F;
            count <= 0;
            result_pipe_1 <= 2'b00;
            valid_pipe_1 <= 1'b0;
        end else begin
            state <= next_state;
            min_char <= next_min_char;
            count <= next_count;
            result_pipe_1 <= next_result_pipe_1;
            valid_pipe_1 <= next_valid_pipe_1;
        end
    end

    // Output Logic (Pipeline Stage 2)
    // Valid output is available 2 cycles after input assertion
    // The input is sampled in the PROCESSING state.
    // The logic above calculates result_pipe_1 in the same cycle as input sample.
    // We register it one more time to meet "2 clock cycles" requirement if interpreted strictly 
    // from the start of processing, or simply output the pipeline stage.
    // Given the prompt: "Result valid 2 clock cycles after character input"
    // Input is seen on Cycle X. 
    // Cycle X+1: result_pipe_1 is calculated. 
    // Cycle X+2: We output result.
    
    reg [1:0] final_result;
    reg final_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_result <= 2'b10; // Invalid on reset
            final_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            // Output pipeline registration
            final_result <= result_pipe_1;
            final_valid <= valid_pipe_1;
            
            // Done signal generation
            if (state == DONE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    assign result = final_result;
    assign valid = final_valid;

endmodule