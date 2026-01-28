module non_decreasing_array (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire data_valid,
    input wire array_end,
    input wire signed [23:0] data_in,
    output reg [5:0] op_count,
    output reg [5:0] op_x,
    output reg [5:0] op_y,
    output reg op_valid,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] READ_INPUT    = 4'd1;
    localparam [3:0] FIND_MAX_ABS  = 4'd2;
    localparam [3:0] DECODE_SIGN   = 4'd3;
    localparam [3:0] OP_ADD_NEG    = 4'd4;
    localparam [3:0] OP_CUM_SUM    = 4'd5;
    localparam [3:0] OP_ADD_POS    = 4'd6;
    localparam [3:0] OP_REV_CUM    = 4'd7;
    localparam [3:0] FINISH        = 4'd8;

    // Constants
    localparam [5:0] MAX_N = 6'd50;
    localparam [5:0] ONE = 6'd1;

    // Internal registers
    reg [3:0] state, next_state;
    reg signed [23:0] arr_reg [0:49]; // Store up to 50 elements
    reg [5:0] n_count;                 // Number of elements read
    reg [5:0] idx;                     // Generic index counter
    reg [5:0] op_gen_idx;              // Index for generating ops
    reg signed [23:0] crit_val;        // Critical element value
    reg [5:0] crit_idx;                // Critical element index (1-based)
    reg [5:0] op_counter;              // Tracks total operations
    reg is_negative;                   // Flag for critical element sign
    reg [5:0] max_abs_idx;             // Temporary index for max abs search
    reg signed [23:0] max_abs_val;     // Temporary max abs value

    // Wires for arithmetic
    wire signed [23:0] abs_val;
    assign abs_val = (data_in[23]) ? -data_in : data_in;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = READ_INPUT;
                else next_state = IDLE;
            end
            READ_INPUT: begin
                if (array_end && data_valid) next_state = FIND_MAX_ABS;
                else if (data_valid) next_state = READ_INPUT;
                else next_state = READ_INPUT;
            end
            FIND_MAX_ABS: begin
                if (n_count >= MAX_N) next_state = DECODE_SIGN;
                else next_state = FIND_MAX_ABS;
            end
            DECODE_SIGN: begin
                if (crit_val >= 24'sd0) next_state = OP_ADD_NEG;
                else next_state = OP_ADD_POS;
            end
            OP_ADD_NEG: begin
                if (op_gen_idx > n_count) next_state = OP_CUM_SUM;
                else next_state = OP_ADD_NEG;
            end
            OP_CUM_SUM: begin
                if (op_gen_idx > n_count) next_state = FINISH;
                else next_state = OP_CUM_SUM;
            end
            OP_ADD_POS: begin
                if (op_gen_idx > n_count) next_state = OP_REV_CUM;
                else next_state = OP_ADD_POS;
            end
            OP_REV_CUM: begin
                if (op_gen_idx < 6'd2) next_state = FINISH;
                else next_state = OP_REV_CUM;
            end
            FINISH: begin
                if (op_gen_idx == 6'd0) next_state = IDLE;
                else next_state = FINISH;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            op_count <= 6'd0;
            op_x <= 6'd0;
            op_y <= 6'd0;
            op_valid <= 1'b0;
            done <= 1'b0;
            n_count <= 6'd0;
            idx <= 6'd0;
            op_gen_idx <= 6'd0;
            crit_val <= 24'sd0;
            crit_idx <= 6'd0;
            op_counter <= 6'd0;
            is_negative <= 1'b0;
            max_abs_idx <= 6'd0;
            max_abs_val <= 24'sd0;
        end else begin
            // Default outputs
            op_valid <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        n_count <= 6'd0;
                        idx <= 6'd0;
                        op_counter <= 6'd0;
                        max_abs_idx <= 6'd0;
                        max_abs_val <= 24'sd0;
                        crit_val <= 24'sd0;
                        crit_idx <= 6'd0;
                    end
                end

                READ_INPUT: begin
                    if (data_valid) begin
                        arr_reg[n_count] <= data_in;
                        n_count <= n_count + 6'd1;
                    end
                end

                FIND_MAX_ABS: begin
                    // Store max absolute value and its index
                    if (idx < n_count) begin
                        if (abs_val > max_abs_val) begin
                            max_abs_val <= abs_val;
                            max_abs_idx <= idx + 6'd1; // Store 1-based index
                            crit_val <= data_in;
                        end
                        idx <= idx + 6'd1;
                    end else begin
                        // Reset index for next state
                        idx <= 6'd0;
                    end
                end

                DECODE_SIGN: begin
                    crit_idx <= max_abs_idx;
                    is_negative <= crit_val[23];
                end

                OP_ADD_NEG: begin
                    // Add critical element to negative elements
                    if (op_gen_idx < n_count) begin
                        op_gen_idx <= op_gen_idx + 6'd1;
                        // Check if element is negative (1-based index in loop)
                        // Note: crit_val is guaranteed positive here
                        if (arr_reg[op_gen_idx][23]) begin
                            op_valid <= 1'b1;
                            op_x <= crit_idx;
                            op_y <= op_gen_idx + 6'd1;
                            op_counter <= op_counter + 6'd1;
                            // Update array in shadow copy for subsequent logic
                            // (Not strictly needed for op generation, but good for consistency)
                        end
                    end else begin
                        op_gen_idx <= 6'd1; // Prepare for cumsum (start at index 1)
                    end
                end

                OP_CUM_SUM: begin
                    // Generate operations: (i, i+1) for i = 1 to N-1
                    if (op_gen_idx < n_count) begin
                        op_valid <= 1'b1;
                        op_x <= op_gen_idx;
                        op_y <= op_gen_idx + 6'd1;
                        op_counter <= op_counter + 6'd1;
                        op_gen_idx <= op_gen_idx + 6'd1;
                    end else begin
                        op_gen_idx <= 6'd0; // Reset for FINISH state logic
                    end
                end

                OP_ADD_POS: begin
                    // Add critical element to positive elements
                    if (op_gen_idx < n_count) begin
                        op_gen_idx <= op_gen_idx + 6'd1;
                        // Check if element is NOT negative (crit_val is negative)
                        if (!arr_reg[op_gen_idx][23] || arr_reg[op_gen_idx] == 24'sd0) begin
                            op_valid <= 1'b1;
                            op_x <= crit_idx;
                            op_y <= op_gen_idx + 6'd1;
                            op_counter <= op_counter + 6'd1;
                        end
                    end else begin
                        op_gen_idx <= n_count; // Prepare for reverse cumsum
                    end
                end

                OP_REV_CUM: begin
                    // Generate operations: (i, i-1) for i = N down to 2
                    if (op_gen_idx > 6'd1) begin
                        op_valid <= 1'b1;
                        op_x <= op_gen_idx;
                        op_y <= op_gen_idx - 6'd1;
                        op_counter <= op_counter + 6'd1;
                        op_gen_idx <= op_gen_idx - 6'd1;
                    end else begin
                        op_gen_idx <= 6'd0;
                    end
                end

                FINISH: begin
                    if (op_gen_idx == 6'd0) begin
                        op_count <= op_counter;
                        done <= 1'b1;
                    end else begin
                        // Wait for done pulse to be seen
                        op_gen_idx <= 6'd0;
                    end
                end
            endcase
        end
    end

endmodule