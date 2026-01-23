module ValidatorArray(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] q,
    input wire [3:0] a_0,
    input wire [3:0] a_1,
    input wire [3:0] a_2,
    input wire [3:0] a_3,
    input wire [3:0] a_4,
    input wire [3:0] a_5,
    input wire [3:0] a_6,
    input wire [3:0] a_7,
    input wire [3:0] a_8,
    input wire [3:0] a_9,
    input wire [3:0] a_10,
    input wire [3:0] a_11,
    input wire [3:0] a_12,
    input wire [3:0] a_13,
    input wire [3:0] a_14,
    input wire [3:0] a_15,
    output reg done,
    output reg valid,
    output reg [3:0] result_0,
    output reg [3:0] result_1,
    output reg [3:0] result_2,
    output reg [3:0] result_3,
    output reg [3:0] result_4,
    output reg [3:0] result_5,
    output reg [3:0] result_6,
    output reg [3:0] result_7,
    output reg [3:0] result_8,
    output reg [3:0] result_9,
    output reg [3:0] result_10,
    output reg [3:0] result_11,
    output reg [3:0] result_12,
    output reg [3:0] result_13,
    output reg [3:0] result_14,
    output reg [3:0] result_15
);

    // State definitions
    localparam [2:0] INIT          = 3'd0;
    localparam [2:0] BACKWARD_PASS = 3'd1;
    localparam [2:0] INIT_FORWARD  = 3'd2;
    localparam [2:0] FORWARD       = 3'd3;
    localparam [2:0] AFTER_FORWARD = 3'd4;
    localparam [2:0] FIND_ZERO     = 3'd5;
    localparam [2:0] OUTPUT_VALID  = 3'd6;
    localparam [2:0] OUTPUT_INVALID = 3'd7;

    // Internal registers
    reg [2:0] state;
    reg [3:0] input_array [0:15];      // Local copy of input
    reg [3:0] output_array [0:15];     // Output result
    reg [3:0] last_occ [0:15];         // Last occurrence indices (0-15 or 4'd15)
    reg [3:0] current_max;
    reg [3:0] idx;
    reg [3:0] value;
    reg [3:0] stack [0:15];            // Stack for max values
    reg [3:0] sp;                      // Stack pointer
    reg invalid_flag;
    reg zero_found;
    reg zero_idx;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= INIT;
            done <= 1'b0;
            valid <= 1'b0;
            current_max <= 4'd0;
            idx <= 4'd0;
            value <= 4'd0;
            sp <= 4'd0;
            invalid_flag <= 1'b0;
            zero_found <= 1'b0;
            zero_idx <= 4'd0;
            result_0 <= 4'd0; result_1 <= 4'd0; result_2 <= 4'd0; result_3 <= 4'd0;
            result_4 <= 4'd0; result_5 <= 4'd0; result_6 <= 4'd0; result_7 <= 4'd0;
            result_8 <= 4'd0; result_9 <= 4'd0; result_10 <= 4'd0; result_11 <= 4'd0;
            result_12 <= 4'd0; result_13 <= 4'd0; result_14 <= 4'd0; result_15 <= 4'd0;
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                input_array[i] <= 4'd0;
                output_array[i] <= 4'd0;
                last_occ[i] <= 4'd15;  // 4'd15 means not found
                stack[i] <= 4'd0;
            end
        end else begin
            case (state)
                INIT: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    current_max <= 4'd0;
                    idx <= 4'd0;
                    value <= 4'd0;
                    sp <= 4'd0;
                    invalid_flag <= 1'b0;
                    zero_found <= 1'b0;
                    zero_idx <= 4'd0;
                    
                    if (start) begin
                        // Load input array
                        input_array[0] <= a_0;
                        input_array[1] <= a_1;
                        input_array[2] <= a_2;
                        input_array[3] <= a_3;
                        input_array[4] <= a_4;
                        input_array[5] <= a_5;
                        input_array[6] <= a_6;
                        input_array[7] <= a_7;
                        input_array[8] <= a_8;
                        input_array[9] <= a_9;
                        input_array[10] <= a_10;
                        input_array[11] <= a_11;
                        input_array[12] <= a_12;
                        input_array[13] <= a_13;
                        input_array[14] <= a_14;
                        input_array[15] <= a_15;
                        idx <= 4'd0;
                        state <= BACKWARD_PASS;
                    end
                end

                BACKWARD_PASS: begin
                    // Scan backward to find last occurrences
                    if (idx < n) begin
                        // idx goes from 0 to n-1, but we scan backward
                        // So actual position is n-1-idx
                        if (input_array[n-1-idx] != 4'd0) begin
                            // Check if already set
                            if (last_occ[input_array[n-1-idx]] == 4'd15) begin
                                last_occ[input_array[n-1-idx]] <= n-1-idx;
                            end
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        // Done backward pass, reset for forward
                        idx <= 4'd0;
                        current_max <= 4'd0;
                        sp <= 4'd0;
                        invalid_flag <= 1'b0;
                        zero_found <= 1'b0;
                        zero_idx <= 4'd0;
                        state <= INIT_FORWARD;
                    end
                end

                INIT_FORWARD: begin
                    // Initialize output with input
                    for (i = 0; i < 16; i = i + 1) begin
                        output_array[i] <= input_array[i];
                    end
                    idx <= 4'd0;
                    state <= FORWARD;
                end

                FORWARD: begin
                    if (idx < n) begin
                        value <= input_array[idx];
                        
                        if (input_array[idx] == 4'd0) begin
                            // Replace zero with current_max or 1
                            if (current_max == 4'd0) begin
                                output_array[idx] <= 4'd1;
                            end else begin
                                output_array[idx] <= current_max;
                            end
                            // Mark first zero found for potential q insertion
                            if (!zero_found) begin
                                zero_found <= 1'b1;
                                zero_idx <= idx;
                            end
                        end else if (input_array[idx] > current_max) begin
                            // Value > current max
                            if (input_array[idx] != last_occ[input_array[idx]]) begin
                                // Not at last occurrence, push and update
                                stack[sp] <= current_max;
                                sp <= sp + 4'd1;
                                current_max <= input_array[idx];
                            end else begin
                                // At last occurrence, just update (no push)
                                current_max <= input_array[idx];
                            end
                        end else if (input_array[idx] == current_max) begin
                            // Value equals current max
                            if (idx == last_occ[current_max]) begin
                                // At last occurrence, pop stack
                                if (sp > 4'd0) begin
                                    sp <= sp - 4'd1;
                                    current_max <= stack[sp-1];
                                end else begin
                                    current_max <= 4'd0;
                                end
                            end
                        end else begin
                            // Value < current max - INVALID
                            invalid_flag <= 1'b1;
                        end
                        
                        idx <= idx + 4'd1;
                    end else begin
                        state <= AFTER_FORWARD;
                    end
                end

                AFTER_FORWARD: begin
                    // Check if max equals q, if not try to set a zero to q
                    if (current_max != q) begin
                        if (zero_found && q > current_max) begin
                            // Insert q at first zero
                            output_array[zero_idx] <= q;
                            current_max <= q;
                        end else begin
                            // Cannot fix
                            invalid_flag <= 1'b1;
                        end
                    end
                    
                    // Move to appropriate output state
                    if (invalid_flag) begin
                        state <= OUTPUT_INVALID;
                    end else begin
                        state <= OUTPUT_VALID;
                    end
                end

                OUTPUT_VALID: begin
                    // Output the restored array
                    result_0 <= output_array[0];
                    result_1 <= output_array[1];
                    result_2 <= output_array[2];
                    result_3 <= output_array[3];
                    result_4 <= output_array[4];
                    result_5 <= output_array[5];
                    result_6 <= output_array[6];
                    result_7 <= output_array[7];
                    result_8 <= output_array[8];
                    result_9 <= output_array[9];
                    result_10 <= output_array[10];
                    result_11 <= output_array[11];
                    result_12 <= output_array[12];
                    result_13 <= output_array[13];
                    result_14 <= output_array[14];
                    result_15 <= output_array[15];
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= INIT;
                end

                OUTPUT_INVALID: begin
                    // Clear outputs for invalid case
                    result_0 <= 4'd0;
                    result_1 <= 4'd0;
                    result_2 <= 4'd0;
                    result_3 <= 4'd0;
                    result_4 <= 4'd0;
                    result_5 <= 4'd0;
                    result_6 <= 4'd0;
                    result_7 <= 4'd0;
                    result_8 <= 4'd0;
                    result_9 <= 4'd0;
                    result_10 <= 4'd0;
                    result_11 <= 4'd0;
                    result_12 <= 4'd0;
                    result_13 <= 4'd0;
                    result_14 <= 4'd0;
                    result_15 <= 4'd0;
                    done <= 1'b1;
                    valid <= 1'b0;
                    state <= INIT;
                end

                default: state <= INIT;
            endcase
        end
    end
endmodule