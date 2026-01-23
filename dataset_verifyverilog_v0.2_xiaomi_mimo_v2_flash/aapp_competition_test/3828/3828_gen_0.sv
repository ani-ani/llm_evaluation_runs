module train_sorter (
    input clk,
    input rst_n,
    input start,
    input [15:0] p_in,
    input [3:0] idx_in,
    output reg [3:0] result,
    output reg done
);

    // Parameters
    parameter N = 16;
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam DONE_STATE = 2'b11;
    
    // Registers
    reg [1:0] state, next_state;
    reg [3:0] count, next_count;          // Load counter (0-15)
    reg [3:0] pos [0:15];                 // Position array: pos[value-1] = position
    reg [3:0] max_seq, next_max_seq;      // Longest sequence found
    reg [3:0] current_seq, next_current_seq; // Current sequence length
    reg [3:0] i, next_i;                  // Loop counter for computation
    reg [3:0] expected, next_expected;    // Expected value in sequence
    
    // Next state logic
    always @(*) begin
        next_state = state;
        next_count = count;
        next_max_seq = max_seq;
        next_current_seq = current_seq;
        next_i = i;
        next_expected = expected;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                    next_count = 4'd0;
                    next_max_seq = 4'd0;
                    next_current_seq = 4'd0;
                    next_i = 4'd0;
                    next_expected = 4'd1;
                end
            end
            
            LOAD: begin
                if (count < N-1) begin
                    next_count = count + 4'd1;
                end else begin
                    next_state = COMPUTE;
                    next_count = 4'd0;
                end
            end
            
            COMPUTE: begin
                if (i < N) begin
                    // Check if pos[i] forms a contiguous increasing sequence
                    if (i == 4'd0) begin
                        // First value always starts a sequence of length 1
                        next_current_seq = 4'd1;
                    end else if (pos[i] > pos[i-1]) begin
                        // Extend current sequence
                        next_current_seq = current_seq + 4'd1;
                    end else begin
                        // Start new sequence
                        next_current_seq = 4'd1;
                    end
                    
                    // Update max sequence
                    if (next_current_seq > max_seq) begin
                        next_max_seq = next_current_seq;
                    end
                    
                    next_i = i + 4'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                // Hold state until reset or new start
                if (start) begin
                    next_state = LOAD;
                    next_count = 4'd0;
                    next_max_seq = 4'd0;
                    next_current_seq = 4'd0;
                    next_i = 4'd0;
                    next_expected = 4'd1;
                end
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            max_seq <= 4'd0;
            current_seq <= 4'd0;
            i <= 4'd0;
            expected <= 4'd1;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            max_seq <= next_max_seq;
            current_seq <= next_current_seq;
            i <= next_i;
            expected <= next_expected;
            
            // Load data into pos array
            if (state == LOAD) begin
                pos[p_in] <= idx_in;
            end
            
            // Output result when done
            if (state == DONE_STATE && next_state != DONE_STATE) begin
                result <= N - max_seq;
                done <= 1'b1;
            end else if (state == IDLE || state == LOAD || state == COMPUTE) begin
                done <= 1'b0;
            end
        end
    end

endmodule