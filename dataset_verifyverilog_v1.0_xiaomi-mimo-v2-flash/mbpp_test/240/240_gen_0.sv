module list_replacer (
    input clk,
    input rst_n,
    input start,
    input [7:0] in1 [0:7],
    input [7:0] in2 [0:7],
    input [3:0] len1,
    input [3:0] len2,
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers and state variables
    reg [1:0] state, next_state;
    reg [3:0] idx;           // Index for result array
    reg [3:0] count;         // Counter for copying elements
    reg [3:0] effective_len1; // Effective length of in1 (capped at 7 to leave room for in2)
    reg [3:0] target_len;    // Target total length (capped at 8)
    reg [7:0] result_reg [0:7]; // Internal result register array
    reg done_reg;

    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            idx <= 4'd0;
            count <= 4'd0;
            effective_len1 <= 4'd0;
            target_len <= 4'd0;
            done_reg <= 1'b0;
            // Initialize result array
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
                result_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            done <= done_reg;
            // Update result output from internal register
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= result_reg[i];
            end

            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    idx <= 4'd0;
                    count <= 4'd0;
                    if (start) begin
                        // Calculate effective lengths
                        // Effective len1: min(len1, 7) to ensure at least 1 slot for in2 if available
                        effective_len1 <= (len1 < 4'd7) ? len1 : 4'd7;
                        // Target length: min(len1 - 1 + len2, 8)
                        // len1 - 1 + len2 = len1 + len2 - 1
                        // Cap at 8
                        target_len <= ((len1 + len2 - 1) < 8) ? (len1 + len2 - 1) : 8;
                    end
                end

                COMPUTE: begin
                    // Copy logic
                    if (count < effective_len1) begin
                        // Copy from in1 first (indices 0 to effective_len1-1)
                        result_reg[count] <= in1[count];
                        count <= count + 1;
                    end else if (idx < (target_len - effective_len1)) begin
                        // Copy from in2 (starting from count position in result)
                        // idx tracks how many from in2 have been copied
                        result_reg[count] <= in2[idx];
                        idx <= idx + 1;
                        count <= count + 1;
                    end else begin
                        // Compute complete
                    end
                end

                FINISH: begin
                    done_reg <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done_reg <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                // Transition when copying is complete
                // Done when idx reaches (target_len - effective_len1) and count reaches effective_len1 + idx
                if (count >= effective_len1 && idx >= (target_len - effective_len1)) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule