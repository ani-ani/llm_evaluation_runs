module DigitSubsetCount(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] COMPUTE  = 3'd2;
    localparam [2:0] FINISH   = 3'd3;

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_DIGITS = 5'd16;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [3:0] digit_count;        // Number of digits to process
    reg [3:0] current_idx;        // Current digit index (0-15)
    reg [3:0] digit_reg;          // Current digit being processed
    reg [3:0] digit_mod3;         // Current digit % 3

    // Storage for digits (0-9)
    reg [3:0] digits [0:15];

    // Counters for subsets by remainder
    reg [31:0] count_mod3 [0:2];

    // Temporary storage for new counts during computation
    reg [31:0] new_count [0:2];

    // Processing state machine
    reg [2:0] compute_state;
    localparam [2:0] COMP_INIT      = 3'd0;
    localparam [2:0] COMP_GET_DIGIT = 3'd1;
    localparam [2:0] COMP_ADD_ZERO  = 3'd2;
    localparam [2:0] COMP_ADD_REMAIN= 3'd3;
    localparam [2:0] COMP_UPDATE    = 3'd4;
    localparam [2:0] COMP_NEXT      = 3'd5;
    localparam [2:0] COMP_DONE      = 3'd6;

    // Loop variables (manual iteration to avoid array issues)
    reg [2:0] rem_idx;

    // Control signals
    reg start_processing;
    reg computation_complete;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            digit_count <= 4'd0;
            current_idx <= 4'd0;
            digit_reg <= 4'd0;
            digit_mod3 <= 3'd0;
            compute_state <= COMP_INIT;
            rem_idx <= 3'd0;
            start_processing <= 1'b0;
            computation_complete <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                digits[i] <= 4'd0;
            end
            count_mod3[0] <= 32'd0;
            count_mod3[1] <= 32'd0;
            count_mod3[2] <= 3'd0;
            new_count[0] <= 32'd0;
            new_count[1] <= 32'd0;
            new_count[2] <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    computation_complete <= 1'b0;
                    if (start) begin
                        digit_count <= len;
                        current_idx <= 4'd0;
                        start_processing <= 1'b1;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load digits from data_in (ASCII '0'-'9' or 0x00)
                    if (current_idx < MAX_DIGITS) begin
                        if (data_in >= 8'h30 && data_in <= 8'h39) begin
                            digits[current_idx] <= data_in - 8'h30;
                        end else begin
                            digits[current_idx] <= 4'd0;
                        end
                        current_idx <= current_idx + 4'd1;
                        if (current_idx + 4'd1 >= digit_count) begin
                            // Pad remaining with 0
                            if (current_idx + 4'd1 < MAX_DIGITS) begin
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (i >= digit_count && i <= current_idx) begin
                                        digits[i] <= 4'd0;
                                    end
                                end
                            end
                            state <= COMPUTE;
                            current_idx <= 4'd0;
                            compute_state <= COMP_INIT;
                        end
                    end else begin
                        state <= COMPUTE;
                        current_idx <= 4'd0;
                        compute_state <= COMP_INIT;
                    end
                end

                COMPUTE: begin
                    // Process digits one by one using state machine
                    case (compute_state)
                        COMP_INIT: begin
                            // Initialize counts
                            count_mod3[0] <= 32'd0;
                            count_mod3[1] <= 32'd0;
                            count_mod3[2] <= 32'd0;
                            current_idx <= 4'd0;
                            if (digit_count == 4'd0) begin
                                computation_complete <= 1'b1;
                                state <= FINISH;
                            end else begin
                                compute_state <= COMP_GET_DIGIT;
                            end
                        end

                        COMP_GET_DIGIT: begin
                            digit_reg <= digits[current_idx];
                            digit_mod3 <= digits[current_idx] % 3'd3;
                            // Initialize new counts with old counts
                            new_count[0] <= count_mod3[0];
                            new_count[1] <= count_mod3[1];
                            new_count[2] <= count_mod3[2];
                            if (digits[current_idx] == 4'd0) begin
                                compute_state <= COMP_ADD_ZERO;
                            end else begin
                                rem_idx <= 3'd0;
                                compute_state <= COMP_ADD_REMAIN;
                            end
                        end

                        COMP_ADD_ZERO: begin
                            // Add subset {0}
                            new_count[0] <= (new_count[0] + 32'd1) % MOD;
                            rem_idx <= 3'd0;
                            compute_state <= COMP_ADD_REMAIN;
                        end

                        COMP_ADD_REMAIN: begin
                            // For each existing remainder r
                            if (rem_idx < 3'd3) begin
                                if (count_mod3[rem_idx] != 32'd0) begin
                                    // Calculate new remainder
                                    // (rem_idx + digit_reg) % 3
                                    // Manual modulo for 3
                                    if (rem_idx < digit_mod3) begin
                                        // Use 3-bit arithmetic for modulo 3
                                        // (a + b) % 3 = (a + b) - 3*((a+b)/3)
                                        // Simplified: ((a + b) % 3)
                                        // rem_idx + digit_reg can be 0..5
                                        // We need to calculate modulo 3
                                        case ((rem_idx + digit_mod3) % 3'd3)
                                            3'd0: new_count[0] <= (new_count[0] + count_mod3[rem_idx]) % MOD;
                                            3'd1: new_count[1] <= (new_count[1] + count_mod3[rem_idx]) % MOD;
                                            3'd2: new_count[2] <= (new_count[2] + count_mod3[rem_idx]) % MOD;
                                        endcase
                                    end else begin
                                        // (rem_idx + digit_reg) % 3
                                        // Manual calculation
                                        case ((rem_idx + digit_mod3) % 3'd3)
                                            3'd0: new_count[0] <= (new_count[0] + count_mod3[rem_idx]) % MOD;
                                            3'd1: new_count[1] <= (new_count[1] + count_mod3[rem_idx]) % MOD;
                                            3'd2: new_count[2] <= (new_count[2] + count_mod3[rem_idx]) % MOD;
                                        endcase
                                    end
                                end
                                rem_idx <= rem_idx + 3'd1;
                            end else begin
                                compute_state <= COMP_UPDATE;
                            end
                        end

                        COMP_UPDATE: begin
                            // Update main counts
                            count_mod3[0] <= new_count[0];
                            count_mod3[1] <= new_count[1];
                            count_mod3[2] <= new_count[2];
                            compute_state <= COMP_NEXT;
                        end

                        COMP_NEXT: begin
                            current_idx <= current_idx + 4'd1;
                            if (current_idx + 4'd1 >= digit_count) begin
                                computation_complete <= 1'b1;
                                state <= FINISH;
                            end else begin
                                compute_state <= COMP_GET_DIGIT;
                            end
                        end

                        default: begin
                            compute_state <= COMP_INIT;
                        end
                    endcase
                end

                FINISH: begin
                    // Output result (count_mod3[0])
                    result <= count_mod3[0];
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