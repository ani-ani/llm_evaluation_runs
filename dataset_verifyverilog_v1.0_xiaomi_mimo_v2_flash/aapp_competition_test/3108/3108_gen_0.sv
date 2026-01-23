module max_avg_consecutive_subarray (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [2:0] K,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] START = 4'd1;
    localparam [3:0] INIT_I = 4'd2;
    localparam [3:0] ACCUM = 4'd3;
    localparam [3:0] COMPARE = 4'd4;
    localparam [3:0] COMPUTE_RESULT = 4'd5;
    localparam [3:0] DONE = 4'd6;

    // Internal registers
    reg [7:0] loaded_arr [0:7];
    reg [15:0] best_sum;
    reg [3:0] best_len;
    reg [15:0] current_sum;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] state;
    reg done_reg;
    reg [31:0] result_reg;
    reg [31:0] temp_product;
    reg [15:0] temp_sum;
    reg [3:0] temp_len;
    reg comparison_result;

    // Loop counter for array initialization
    reg [2:0] init_idx;

    integer counter;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            done_reg <= 1'b0;
            result_reg <= 32'd0;
            best_sum <= 16'd0;
            best_len <= 4'd0;
            current_sum <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp_product <= 32'd0;
            temp_sum <= 16'd0;
            temp_len <= 4'd0;
            comparison_result <= 1'b0;
            counter <= 0;
            init_idx <= 3'd0;
            // Initialize loaded_arr to avoid X
            loaded_arr[0] <= 8'd0;
            loaded_arr[1] <= 8'd0;
            loaded_arr[2] <= 8'd0;
            loaded_arr[3] <= 8'd0;
            loaded_arr[4] <= 8'd0;
            loaded_arr[5] <= 8'd0;
            loaded_arr[6] <= 8'd0;
            loaded_arr[7] <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            // Default output assignment
            done <= done_reg;
            result <= result_reg;
            counter <= counter + 1;

            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    counter <= 8'd0;
                    if (start) begin
                        state <= START;
                    end
                end

                START: begin
                    // Latch input array
                    loaded_arr[0] <= arr_0;
                    loaded_arr[1] <= arr_1;
                    loaded_arr[2] <= arr_2;
                    loaded_arr[3] <= arr_3;
                    loaded_arr[4] <= arr_4;
                    loaded_arr[5] <= arr_5;
                    loaded_arr[6] <= arr_6;
                    loaded_arr[7] <= arr_7;
                    
                    best_sum <= 16'd0;
                    best_len <= 4'd0;
                    i <= 4'd0;
                    state <= INIT_I;
                end

                INIT_I: begin
                    j <= i;
                    current_sum <= 16'd0;
                    // Check if i + K - 1 >= 8 (i + K > 8)
                    if ((i + K) > 8'd8) begin
                        state <= COMPUTE_RESULT;
                    end else begin
                        state <= ACCUM;
                    end
                end

                ACCUM: begin
                    current_sum <= current_sum + loaded_arr[j];
                    j <= j + 4'd1;
                    if (j < (i + K - 4'd1)) begin
                        state <= ACCUM;
                    end else begin
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Cross-multiplication: (current_sum / (j-i)) > (best_sum / best_len)
                    // current_sum * best_len > best_sum * (j-i)
                    if (best_len == 4'd0) begin
                        // First subarray found, always better
                        comparison_result <= 1'b1;
                    end else begin
                        temp_product <= current_sum * best_len;
                        if ((current_sum * best_len) > (best_sum * (j - i))) begin
                            comparison_result <= 1'b1;
                        end else begin
                            comparison_result <= 1'b0;
                        end
                    end

                    // Update if current is better
                    if (best_len == 4'd0 || comparison_result) begin
                        best_sum <= current_sum;
                        best_len <= j - i;
                    end

                    // Continue to next j or next i
                    if (j < 8'd8) begin
                        current_sum <= current_sum + loaded_arr[j];
                        j <= j + 4'd1;
                        state <= COMPARE;
                    end else begin
                        i <= i + 4'd1;
                        state <= INIT_I;
                    end
                end

                COMPUTE_RESULT: begin
                    // result = (best_sum * 65536) / best_len
                    // Avoid division by zero (should not happen with valid K >= 1)
                    if (best_len != 4'd0) begin
                        temp_product <= {16'd0, best_sum} << 16; // best_sum * 65536
                        result_reg <= ({16'd0, best_sum} << 16) / best_len;
                    end else begin
                        result_reg <= 32'd0;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done_reg <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Safety: timeout
            if (counter >= MAX_CYCLES) begin
                state <= IDLE;
                done_reg <= 1'b0;
            end
        end
    end

endmodule