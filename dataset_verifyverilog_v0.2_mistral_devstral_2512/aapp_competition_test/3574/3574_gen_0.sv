module magical_subarray (
    input clk,
    input rst_n,
    input start,
    input [7:0] array_data [0:7],
    input [2:0] query_L,
    input [2:0] query_R,
    output reg [3:0] result,
    output reg done
);

    reg [2:0] i;
    reg [2:0] j;
    reg [2:0] k;
    reg [7:0] c_min;
    reg [7:0] c_max;
    reg [3:0] max_len;
    reg valid_flag;

    localparam S_IDLE = 0;
    localparam S_INIT = 1;
    localparam S_LOOP_I = 2;
    localparam S_LOOP_J = 3;
    localparam S_SCAN_MIN_MAX = 4;
    localparam S_CHECK_MAGICAL = 5;
    localparam S_UPDATE = 6;
    localparam S_DONE = 7;

    reg [3:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) state <= S_INIT;
                end

                S_INIT: begin
                    i <= query_L;
                    max_len <= 0;
                    state <= S_LOOP_I;
                end

                S_LOOP_I: begin
                    if (i <= query_R) begin
                        j <= i;
                        state <= S_LOOP_J;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_LOOP_J: begin
                    if (j <= query_R) begin
                        k <= i;
                        c_min <= array_data[i];
                        c_max <= array_data[i];
                        state <= S_SCAN_MIN_MAX;
                    end else begin
                        i <= i + 1;
                        state <= S_LOOP_I;
                    end
                end

                S_SCAN_MIN_MAX: begin
                    if (k < j) begin
                        k <= k + 1;
                        if (array_data[k] < c_min) c_min <= array_data[k];
                        if (array_data[k] > c_max) c_max <= array_data[k];
                    end else begin
                        k <= i;
                        valid_flag <= 1;
                        state <= S_CHECK_MAGICAL;
                    end
                end

                S_CHECK_MAGICAL: begin
                    if (k <= j) begin
                        if (array_data[k] < c_min || array_data[k] > c_max) begin
                            valid_flag <= 0;
                            state <= S_UPDATE;
                        end else begin
                            k <= k + 1;
                        end
                    end else begin
                        state <= S_UPDATE;
                    end
                end

                S_UPDATE: begin
                    if (valid_flag) begin
                        if (j - i + 1 > max_len) max_len <= j - i + 1;
                    end
                    j <= j + 1;
                    state <= S_LOOP_J;
                end

                S_DONE: begin
                    result <= max_len;
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule