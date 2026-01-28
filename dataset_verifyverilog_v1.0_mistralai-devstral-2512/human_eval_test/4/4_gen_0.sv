module mad_calculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SUM     = 3'd1;
    localparam [2:0] MEAN    = 3'd2;
    localparam [2:0] DIFF    = 3'd3;
    localparam [2:0] ACCUM   = 3'd4;
    localparam [2:0] OUTPUT  = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [15:0] sum;
    reg [7:0] mean;
    reg signed [15:0] diff;
    reg [15:0] abs_diff_sum;
    reg [7:0] mad;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd60;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            sum <= 16'd0;
            mean <= 8'd0;
            diff <= 16'd0;
            abs_diff_sum <= 16'd0;
            mad <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SUM;
                        index <= 4'd0;
                        sum <= 16'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        sum <= sum + arr[index];
                        index <= index + 4'd1;
                        next_state <= SUM;
                    end else begin
                        next_state <= MEAN;
                    end
                end

                MEAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    mean <= sum / len;
                    next_state <= DIFF;
                    index <= 4'd0;
                    abs_diff_sum <= 16'd0;
                end

                DIFF: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        diff <= arr[index] - mean;
                        if (diff[15]) begin
                            abs_diff_sum <= abs_diff_sum - diff;
                        end else begin
                            abs_diff_sum <= abs_diff_sum + diff;
                        end
                        index <= index + 4'd1;
                        next_state <= DIFF;
                    end else begin
                        next_state <= ACCUM;
                    end
                end

                ACCUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    mad <= abs_diff_sum / len;
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= {8'd0, mad};
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule