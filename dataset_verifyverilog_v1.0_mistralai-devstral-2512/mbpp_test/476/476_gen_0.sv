module min_max_sum(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:15],
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] FINISH  = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] counter;
    reg signed [7:0] current_min, current_max;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            counter <= 4'd0;
            current_min <= 8'd0;
            current_max <= 8'd0;
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
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    current_min <= arr[0];
                    current_max <= arr[0];
                    counter <= 4'd1;
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (arr[counter] < current_min) begin
                        current_min <= arr[counter];
                    end
                    if (arr[counter] > current_max) begin
                        current_max <= arr[counter];
                    end
                    if (counter == 4'd15 || cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        counter <= counter + 4'd1;
                        next_state <= COMPARE;
                    end
                end

                FINISH: begin
                    result <= current_min + current_max;
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