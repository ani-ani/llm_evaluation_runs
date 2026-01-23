module robber_watches (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] m,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam GENERATE_PERM = 3'b001;
    localparam CHECK_VALID = 3'b010;
    localparam UPDATE_COUNT = 3'b011;
    localparam DONE = 3'b100;

    // State register
    reg [2:0] state;

    // Permutation generation variables
    reg [5:0] perm_index; // Index for permutation (0 to 119 for 5!)
    reg [2:0] hour_digits [0:2]; // 3 digits for hours
    reg [2:0] min_digits [0:1]; // 2 digits for minutes

    // Intermediate values
    reg [15:0] count;
    reg [7:0] current_hour;
    reg [7:0] current_min;

    // Permutation generation using Heap's algorithm
    reg [5:0] stack_ptr;
    reg [2:0] digits [0:4]; // 5 digits total (3+2)
    reg [2:0] swap_temp;
    reg [2:0] temp_digit;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            perm_index <= 0;
            count <= 0;
            result <= 0;
            done <= 0;
            stack_ptr <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= GENERATE_PERM;
                        perm_index <= 0;
                        count <= 0;
                        done <= 0;
                        // Initialize digits array
                        digits[0] <= 0;
                        digits[1] <= 1;
                        digits[2] <= 2;
                        digits[3] <= 3;
                        digits[4] <= 4;
                    end
                end

                GENERATE_PERM: begin
                    // Generate next permutation using Heap's algorithm
                    if (perm_index < 120) begin
                        // Heap's algorithm implementation
                        if (stack_ptr == 0) begin
                            // Generate next permutation
                            if (perm_index == 0) begin
                                // First permutation is already set
                            end else begin
                                // Find the largest i such that c[i] < c[i+1]
                                integer i;
                                for (i = 3; i >= 0; i = i - 1) begin
                                    if (digits[i] < digits[i+1]) begin
                                        // Find the largest j such that c[i] < c[j]
                                        integer j;
                                        for (j = 4; j > i; j = j - 1) begin
                                            if (digits[i] < digits[j]) begin
                                                // Swap c[i] and c[j]
                                                swap_temp = digits[i];
                                                digits[i] = digits[j];
                                                digits[j] = swap_temp;
                                                break;
                                            end
                                        end
                                        // Reverse the suffix
                                        integer k;
                                        for (k = 0; k < (4 - i)/2; k = k + 1) begin
                                            temp_digit = digits[i + 1 + k];
                                            digits[i + 1 + k] = digits[4 - k];
                                            digits[4 - k] = temp_digit;
                                        end
                                        break;
                                    end
                                end
                            end
                            state <= CHECK_VALID;
                        end else begin
                            // Push to stack (not needed for this implementation)
                            state <= CHECK_VALID;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                CHECK_VALID: begin
                    // Extract hour and minute digits
                    hour_digits[0] = digits[0];
                    hour_digits[1] = digits[1];
                    hour_digits[2] = digits[2];
                    min_digits[0] = digits[3];
                    min_digits[1] = digits[4];

                    // Convert to decimal
                    current_hour = hour_digits[0] * 49 + hour_digits[1] * 7 + hour_digits[2];
                    current_min = min_digits[0] * 7 + min_digits[1];

                    // Check bounds
                    if (current_hour < n && current_min < m) begin
                        state <= UPDATE_COUNT;
                    end else begin
                        state <= GENERATE_PERM;
                        perm_index <= perm_index + 1;
                    end
                end

                UPDATE_COUNT: begin
                    count <= count + 1;
                    state <= GENERATE_PERM;
                    perm_index <= perm_index + 1;
                end

                DONE: begin
                    result <= count;
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule