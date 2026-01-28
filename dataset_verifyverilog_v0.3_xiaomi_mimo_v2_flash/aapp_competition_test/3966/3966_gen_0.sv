module appleman_toastman #(
    parameter MAX_N = 4,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] len,
    input wire [DATA_WIDTH-1:0] arr_0,
    input wire [DATA_WIDTH-1:0] arr_1,
    input wire [DATA_WIDTH-1:0] arr_2,
    input wire [DATA_WIDTH-1:0] arr_3,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CAPTURE    = 3'd1;
    localparam [2:0] SORT_LOOP  = 3'd2;
    localparam [2:0] COMPUTE_SUM = 3'd3;
    localparam [2:0] SUBTRACT   = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [DATA_WIDTH-1:0] array_reg [0:MAX_N-1];
    reg [2:0] i_idx;
    reg [2:0] j_idx;
    reg [RESULT_WIDTH-1:0] sum_reg;
    reg [RESULT_WIDTH-1:0] weighted_value;
    reg [2:0] current_idx;
    reg sorted;
    reg [2:0] cycle_counter;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            for (k = 0; k < MAX_N; k = k + 1) begin
                array_reg[k] <= 8'd0;
            end
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            sum_reg <= 16'd0;
            weighted_value <= 16'd0;
            current_idx <= 3'd0;
            sorted <= 1'b0;
            cycle_counter <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 3'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    // Capture input array when start is asserted
                    array_reg[0] <= arr_0;
                    array_reg[1] <= arr_1;
                    array_reg[2] <= arr_2;
                    array_reg[3] <= arr_3;
                    i_idx <= 3'd0;
                    j_idx <= 3'd0;
                    sorted <= 1'b0;
                    state <= SORT_LOOP;
                end

                SORT_LOOP: begin
                    // Bubble sort algorithm
                    if (i_idx < len - 3'd1) begin
                        if (j_idx < len - 3'd1 - i_idx) begin
                            // Compare and swap if needed
                            if (array_reg[j_idx] > array_reg[j_idx + 3'd1]) begin
                                array_reg[j_idx] <= array_reg[j_idx + 3'd1];
                                array_reg[j_idx + 3'd1] <= array_reg[j_idx];
                            end
                            j_idx <= j_idx + 3'd1;
                        end else begin
                            j_idx <= 3'd0;
                            i_idx <= i_idx + 3'd1;
                        end
                    end else begin
                        sorted <= 1'b1;
                        state <= COMPUTE_SUM;
                        sum_reg <= 16'd0;
                        current_idx <= 3'd0;
                    end
                end

                COMPUTE_SUM: begin
                    // Compute weighted sum: sorted_array[i] * (i+2)
                    if (current_idx < len) begin
                        // Multiply by (current_idx + 2)
                        case (current_idx)
                            3'd0: weighted_value <= {8'd0, array_reg[0]} * 4'd2;
                            3'd1: weighted_value <= {8'd0, array_reg[1]} * 4'd3;
                            3'd2: weighted_value <= {8'd0, array_reg[2]} * 4'd4;
                            3'd3: weighted_value <= {8'd0, array_reg[3]} * 4'd5;
                            default: weighted_value <= 16'd0;
                        endcase
                        current_idx <= current_idx + 3'd1;
                        state <= SUBTRACT;
                    end else begin
                        // Done computing sum
                        state <= FINISH;
                    end
                end

                SUBTRACT: begin
                    // Add weighted value to sum
                    sum_reg <= sum_reg + weighted_value;
                    state <= COMPUTE_SUM;
                end

                FINISH: begin
                    // Subtract largest element (sorted_array[len-1])
                    result <= sum_reg - {8'd0, array_reg[len - 3'd1]};
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