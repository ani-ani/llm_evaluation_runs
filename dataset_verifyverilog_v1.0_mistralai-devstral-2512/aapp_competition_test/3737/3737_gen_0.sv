module steward_support(
    input clk,
    input rst_n,
    input start,
    input [31:0] values [0:15],
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN_MIN_MAX = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [31:0] min_val, max_val;
    reg [15:0] count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            min_val <= 32'd0;
            max_val <= 32'd0;
            count <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SCAN_MIN_MAX;
                        index <= 4'd0;
                        min_val <= values[0];
                        max_val <= values[0];
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN_MIN_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < n) begin
                        if (values[index] < min_val) begin
                            min_val <= values[index];
                        end
                        if (values[index] > max_val) begin
                            max_val <= values[index];
                        end
                        index <= index + 4'd1;
                        next_state <= SCAN_MIN_MAX;
                    end else begin
                        if (n <= 2 || min_val == max_val) begin
                            count <= 16'd0;
                            next_state <= DONE_STATE;
                        end else begin
                            index <= 4'd0;
                            count <= 16'd0;
                            next_state <= COUNT;
                        end
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < n) begin
                        if (values[index] > min_val && values[index] < max_val) begin
                            count <= count + 16'd1;
                        end
                        index <= index + 4'd1;
                        next_state <= COUNT;
                    end else begin
                        result <= count;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
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