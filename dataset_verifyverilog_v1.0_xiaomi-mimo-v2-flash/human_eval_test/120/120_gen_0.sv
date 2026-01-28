module FindMaxSorted (
    input clk,
    input rst_n,
    input start,
    input signed [8:0] arr [0:15],
    input [4:0] k,
    input [15:0] arr_valid,
    output reg signed [8:0] result [0:15],
    output reg [15:0] result_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] FIND_MAX   = 3'd1;
    localparam [2:0] REMOVE_MAX = 3'd2;
    localparam [2:0] SORT       = 3'd3;
    localparam [2:0] FINISH     = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] i, j;          // Array indices
    reg [4:0] count;         // Number of max values found
    reg [4:0] k_reg;         // Store k
    reg signed [8:0] temp_max;
    reg signed [8:0] temp_val;
    reg [15:0] temp_valid;
    reg [3:0] swap_idx;      // For sorting
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd31;

    // Internal array for storing found max values
    reg signed [8:0] max_values [0:15];
    reg [15:0] max_valid;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 16'd0;
            count <= 5'd0;
            cycle_count <= 5'd0;
            max_valid <= 16'd0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                result[idx] <= 9'sd0;
                max_values[idx] <= 9'sd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    count <= 5'd0;
                    max_valid <= 16'd0;
                    if (start) begin
                        k_reg <= k;
                        if (k > 16) k_reg <= 5'd16;
                        else k_reg <= k;
                        state <= FIND_MAX;
                        i <= 4'd0;
                        temp_max <= 9'sh200; // Minimum signed 9-bit
                        temp_valid <= arr_valid;
                    end
                end

                FIND_MAX: begin
                    if (i < 16) begin
                        if (temp_valid[i]) begin
                            if (arr[i] > temp_max) begin
                                temp_max <= arr[i];
                                swap_idx <= i;
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (temp_valid != 16'd0 && count < k_reg) begin
                            state <= REMOVE_MAX;
                            i <= 4'd0;
                        end else begin
                            state <= SORT;
                            j <= 4'd0;
                        end
                    end
                end

                REMOVE_MAX: begin
                    if (i < 16) begin
                        if (temp_valid[i] && arr[i] == temp_max) begin
                            temp_valid[i] <= 1'b0;
                            max_values[count] <= temp_max;
                            max_valid[count] <= 1'b1;
                            count <= count + 5'd1;
                            i <= 4'd15; // Skip to end
                        end
                        i <= i + 4'd1;
                    end else begin
                        state <= FIND_MAX;
                        i <= 4'd0;
                        temp_max <= 9'sh200;
                    end
                end

                SORT: begin
                    if (count > 1 && j < count - 1) begin
                        for (i = 0; i < count - 1 - j; i = i + 1) begin
                            if (max_values[i] > max_values[i + 1]) begin
                                temp_val <= max_values[i];
                                max_values[i] <= max_values[i + 1];
                                max_values[i + 1] <= temp_val;
                            end
                        end
                        j <= j + 4'd1;
                    end else begin
                        state <= FINISH;
                        i <= 4'd0;
                    end
                end

                FINISH: begin
                    if (i < 16) begin
                        if (i < count) begin
                            result[i] <= max_values[i];
                            result_valid[i] <= 1'b1;
                        end else begin
                            result[i] <= 9'sd0;
                            result_valid[i] <= 1'b0;
                        end
                        i <= i + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                        done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule