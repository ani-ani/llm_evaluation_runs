module BubbleSort16(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire signed [7:0] arr_in [0:15],
    output reg signed [7:0] arr_out [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CAPTURE    = 3'd1;
    localparam [2:0] OUTER_LOOP = 3'd2;
    localparam [2:0] INNER_LOOP = 3'd3;
    localparam [2:0] COMPARE    = 3'd4;
    localparam [2:0] OUTPUT     = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg signed [7:0] reg_array [0:15];  // Working array
    reg [3:0] i;  // Outer loop index (0 to len-2)
    reg [3:0] j;  // Inner loop index (0 to len-2-i)
    reg [3:0] len_reg;  // Captured length
    reg signed [7:0] temp;  // Temporary for swap
    reg [10:0] cycle_count;  // Prevent infinite loops (max 2048)
    localparam [10:0] MAX_CYCLES = 11'd1000;
    integer idx;  // For array initialization/copying

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Initialize all regs
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            len_reg <= 4'd0;
            temp <= 8'd0;
            cycle_count <= 11'd0;
            // Initialize output array
            for (idx = 0; idx < 16; idx = idx + 1) begin
                arr_out[idx] <= 8'd0;
                reg_array[idx] <= 8'd0;
            end
        end else begin
            state <= next_state;
            // Default done clear (except when asserted in FINISH)
            if (state != FINISH) begin
                done <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CAPTURE;
                end else begin
                    next_state = IDLE;
                end
            end
            CAPTURE: begin
                next_state = (len_reg <= 4'd1) ? OUTPUT : OUTER_LOOP;
            end
            OUTER_LOOP: begin
                if (i >= len_reg - 4'd1) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = INNER_LOOP;
                end
            end
            INNER_LOOP: begin
                if (j >= (len_reg - 4'd2 - i)) begin
                    next_state = OUTER_LOOP;
                end else begin
                    next_state = COMPARE;
                end
            end
            COMPARE: begin
                next_state = INNER_LOOP;
            end
            OUTPUT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else begin
            case (state)
                CAPTURE: begin
                    // Copy first len elements
                    len_reg <= len;
                    cycle_count <= 11'd0;
                    // Use combinational loop for assignment
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        if (idx < len) begin
                            reg_array[idx] <= arr_in[idx];
                        end else begin
                            reg_array[idx] <= 8'd0;
                        end
                    end
                end
                OUTER_LOOP: begin
                    i <= 4'd0;
                    j <= 4'd0;
                end
                INNER_LOOP: begin
                    // Reset j at start of each outer iteration
                    if (j == 4'd0 && i == 4'd0 && state != COMPARE) begin
                        j <= 4'd0;
                    end
                    cycle_count <= cycle_count + 11'd1;
                end
                COMPARE: begin
                    if (reg_array[j] > reg_array[j+1]) begin
                        // Swap
                        temp <= reg_array[j];
                        reg_array[j] <= reg_array[j+1];
                        reg_array[j+1] <= temp;
                    end
                    j <= j + 4'd1;
                end
                OUTPUT: begin
                    // Copy to output array
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        if (idx < len_reg) begin
                            arr_out[idx] <= reg_array[idx];
                        end else begin
                            arr_out[idx] <= 8'd0;
                        end
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: begin
                    // No action
                end
            endcase
        end
    end

    // Inner loop counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            j <= 4'd0;
        end else begin
            case (state)
                OUTER_LOOP: begin
                    j <= 4'd0;
                end
                COMPARE: begin
                    if (j < (len_reg - 4'd2 - i)) begin
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;  // Reset for next outer iteration
                    end
                end
                INNER_LOOP: begin
                    if (j == 4'd0 && i == 4'd0) begin
                        j <= 4'd0;
                    end
                end
                default: begin
                    // No change
                end
            endcase
        end
    end

    // Outer loop counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 4'd0;
        end else begin
            case (state)
                OUTER_LOOP: begin
                    if (i < len_reg - 4'd2) begin
                        // Wait for inner loop to complete
                        if (j == 4'd0 && i != 4'd0) begin
                            i <= i + 4'd1;
                        end else if (i == 4'd0) begin
                            // First iteration
                            i <= 4'd0;
                        end
                    end
                end
                INNER_LOOP: begin
                    if (j == 0 && i > 0) begin
                        i <= i + 4'd1;
                    end
                end
                COMPARE: begin
                    if (j == (len_reg - 4'd2 - i)) begin
                        // Last comparison in this inner loop
                        // i will be incremented in next OUTER_LOOP cycle
                    end
                end
                default: begin
                    // No change
                end
            endcase
        end
    end

endmodule