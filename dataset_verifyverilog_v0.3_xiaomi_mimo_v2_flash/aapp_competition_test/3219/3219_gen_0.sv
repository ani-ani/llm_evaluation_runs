module count_representations (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [MAX_BITS-1:0] bin_bits,
    input wire [LOG_MAX_BITS-1:0] length,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    parameter MAX_BITS = 16;
    parameter LOG_MAX_BITS = 4;
    parameter MOD = 1000000009;
    parameter RESULT_WIDTH = 32;

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [RESULT_WIDTH-1:0] dp0, next_dp0;
    reg [RESULT_WIDTH-1:0] dp1, next_dp1;
    reg [LOG_MAX_BITS-1:0] index, next_index;
    reg [RESULT_WIDTH-1:0] temp_sum;
    reg [7:0] cycle_count;

    function automatic [RESULT_WIDTH-1:0] mod_add;
        input [RESULT_WIDTH-1:0] a, b;
        reg [RESULT_WIDTH-1:0] sum;
        begin
            sum = a + b;
            if (sum >= MOD)
                mod_add = sum - MOD;
            else
                mod_add = sum;
        end
    endfunction

    always @(*) begin
        next_state = state;
        next_dp0 = dp0;
        next_dp1 = dp1;
        next_index = index;
        result = result;
        done = done;
        temp_sum = 0;

        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = PROCESS;
                    next_dp0 = 1;
                    next_dp1 = 0;
                    next_index = 0;
                end
            end

            PROCESS: begin
                if (bin_bits[index] == 1'b0) begin
                    temp_sum = mod_add(dp0, dp1);
                    next_dp0 = dp0;
                    next_dp1 = temp_sum;
                end else begin
                    temp_sum = mod_add(dp0, dp1);
                    next_dp0 = temp_sum;
                    next_dp1 = dp1;
                end

                if (index == length - 1) begin
                    if (bin_bits[index] == 1'b0) begin
                        result = dp0;
                    end else begin
                        result = temp_sum;
                    end
                    next_state = FINISH;
                end else begin
                    next_index = index + 1;
                end
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            dp0 <= 0;
            dp1 <= 0;
            index <= 0;
            result <= 0;
            done <= 1'b0;
            cycle_count <= 0;
        end else begin
            state <= next_state;
            dp0 <= next_dp0;
            dp1 <= next_dp1;
            index <= next_index;
            cycle_count <= cycle_count + 1;
        end
    end

endmodule