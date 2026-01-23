module pair_xor_sum (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] i, next_i; // Outer loop index
    reg [2:0] j, next_j; // Inner loop index
    reg [15:0] result_reg, next_result;
    reg done_reg, next_done;

    // State register and synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 3'b0;
            j <= 3'b0;
            result_reg <= 16'b0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            result_reg <= next_result;
            done_reg <= next_done;
        end
    end

    // Output assignments
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end

    // Next state logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_i = i;
        next_j = j;
        next_result = result_reg;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_i = 3'b0;
                    next_j = 3'b1;
                    next_result = 16'b0;
                end else begin
                    next_state = IDLE;
                    next_i = 3'b0;
                    next_j = 3'b0;
                    next_result = 16'b0;
                end
            end

            PROCESSING: begin
                // Check for valid indices and boundary conditions
                // We need to check if i < n and j < n
                // If i >= n or (i < n and j >= n), we are done
                
                if (i >= n || (i < n && j >= n)) begin
                    // Current pair processing finished, move to next pair
                    if (i + 1 >= n || (i + 1 < n && i + 2 >= n)) begin
                        // Outer loop finished or only 0 or 1 element left
                        next_state = DONE;
                        next_i = 3'b0;
                        next_j = 3'b0;
                        next_result = result_reg;
                        next_done = 1'b1;
                    end else begin
                        // Increment i, reset j to i+1
                        next_i = i + 1;
                        next_j = i + 2; // j = i + 1 + 1 (since we add current pair then increment)
                        next_result = result_reg;
                        next_state = PROCESSING;
                    end
                end else begin
                    // Process current pair (i, j)
                    next_result = result_reg + (arr[i] ^ arr[j]);
                    
                    // Move j to next
                    if (j + 1 < n) begin
                        next_j = j + 1;
                        next_i = i;
                        next_state = PROCESSING;
                    end else begin
                        // j reached end, increment i and reset j
                        if (i + 1 < n) begin
                            next_i = i + 1;
                            next_j = i + 2; // New j starts at i + 1 (which is the new i) + 1
                            next_state = PROCESSING;
                        end else begin
                            // i also reached end (n-1)
                            next_state = DONE;
                            next_i = 3'b0;
                            next_j = 3'b0;
                            next_done = 1'b1;
                        end
                    end
                end
            end

            DONE: begin
                next_state = IDLE;
                next_i = 3'b0;
                next_j = 3'b0;
                next_result = 16'b0;
                next_done = 1'b0;
            end

            default: begin
                next_state = IDLE;
                next_i = 3'b0;
                next_j = 3'b0;
                next_result = 16'b0;
                next_done = 1'b0;
            end
        endcase
    end

endmodule