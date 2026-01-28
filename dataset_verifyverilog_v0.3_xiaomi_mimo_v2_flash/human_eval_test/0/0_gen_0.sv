module has_close_elements (
    input clk,
    input rst_n,
    input start,
    input [31:0] threshold,
    input [31:0] arr_0,
    input [31:0] arr_1,
    input [31:0] arr_2,
    input [31:0] arr_3,
    input [31:0] arr_4,
    input [31:0] arr_5,
    input [31:0] arr_6,
    input [31:0] arr_7,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers for state and counters
    reg [1:0] state;
    reg [3:0] i;           // Outer loop index (0 to 6)
    reg [3:0] j;           // Inner loop index (i+1 to 7)
    reg [5:0] cycle_count; // Prevent infinite loops (max 28 comparisons)
    localparam [5:0] MAX_CYCLES = 6'd40; // Safe upper bound

    // Arrays for input storage
    reg [31:0] arr [0:7];

    // Computation registers
    reg signed [32:0] diff; // 33-bit signed for subtraction
    reg unsigned [31:0] abs_diff; // 32-bit unsigned for comparison
    reg temp_result;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd1;
            cycle_count <= 6'd0;
            temp_result <= 1'b0;
            diff <= 33'sd0;
            abs_diff <= 32'd0;
            // Initialize array
            for (idx = 0; idx < 8; idx = idx + 1) begin
                arr[idx] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    i <= 4'd0;
                    j <= 4'd1;
                    temp_result <= 1'b0;
                    
                    if (start) begin
                        // Store inputs into array
                        arr[0] <= arr_0;
                        arr[1] <= arr_1;
                        arr[2] <= arr_2;
                        arr[3] <= arr_3;
                        arr[4] <= arr_4;
                        arr[5] <= arr_5;
                        arr[6] <= arr_6;
                        arr[7] <= arr_7;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 6'd1;

                    // Calculate signed difference
                    diff <= $signed({1'b0, arr[i]}) - $signed({1'b0, arr[j]});

                    // Check sign bit (bit 32) and take absolute value
                    if (diff[32]) begin
                        abs_diff <= -diff[31:0];
                    end else begin
                        abs_diff <= diff[31:0];
                    end

                    // Compare with threshold
                    if (abs_diff < threshold) begin
                        temp_result <= 1'b1;
                    end

                    // Update indices for next pair
                    if (j < 7) begin
                        j <= j + 4'd1;
                    end else begin
                        j <= i + 4'd2;
                        i <= i + 4'd1;
                    end

                    // Exit conditions
                    if ((i == 4'd6 && j == 4'd7) || (cycle_count >= MAX_CYCLES)) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= temp_result;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule