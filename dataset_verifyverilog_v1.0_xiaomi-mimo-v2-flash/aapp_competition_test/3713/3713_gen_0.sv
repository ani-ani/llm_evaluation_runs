module alt_subseq (
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [63:0] data,
    output reg [6:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] CALCULATE  = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    reg [2:0] state;
    reg [5:0] i;                // Iterator for n
    reg [6:0] C;                // Count of transitions
    reg has_collision;          // Flag for adjacent equal bits
    reg prev_bit;               // Previous bit in sequence
    reg [6:0] base_len;         // C + 1
    reg [6:0] temp_result;      // Intermediate result

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 7'd0;
            done <= 1'b0;
            i <= 6'd0;
            C <= 7'd0;
            has_collision <= 1'b0;
            prev_bit <= 1'b0;
            base_len <= 7'd0;
            temp_result <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 6'd0;
                    C <= 7'd0;
                    has_collision <= 1'b0;
                    prev_bit <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load initial values based on n
                    if (n > 6'd0) begin
                        prev_bit <= data[0];
                        i <= 6'd1; // Start checking from index 1
                    end
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    if (i < n) begin
                        // Check if current bit differs from previous
                        if (data[i] != prev_bit) begin
                            C <= C + 7'd1;
                        end else begin
                            has_collision <= 1'b1;
                        end
                        prev_bit <= data[i];
                        i <= i + 6'd1;
                        // Stay in COMPUTE
                    end else begin
                        // Done iterating
                        state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    // Base length is C + 1 (number of elements in subsequence)
                    base_len <= C + 7'd1;
                    
                    if (has_collision) begin
                        temp_result <= C + 7'd1 + 7'd2;
                    end else begin
                        // No collision found internally
                        if (n > 6'd1) begin
                            // Strictly alternating, so add 1
                            temp_result <= C + 7'd1 + 7'd1;
                        end else begin
                            // n == 1
                            temp_result <= 7'd1;
                        end
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    // Clamp to n (max length cannot exceed n)
                    if (temp_result[6] && temp_result > 7'd64) begin
                        // Unlikely for this algorithm logic, but safe clamp
                        result <= 7'd64;
                    end else if (temp_result > {1'b0, n}) begin
                        result <= {1'b0, n};
                    end else begin
                        result <= temp_result;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule