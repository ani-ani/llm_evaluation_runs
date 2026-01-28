module next_smallest_finder(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:7],
    input [3:0] len,
    output reg signed [7:0] result,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] FINISH    = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] min1, min2;
    reg [3:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            min1 <= 8'd0;
            min2 <= 8'd0;
            index <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    next_state = PROCESS;
                    index <= 4'd0;
                    cycle_count <= 8'd0;
                    min1 <= 8'd127;
                    min2 <= 8'd127;
                end
            end

            PROCESS: begin
                cycle_count <= cycle_count + 8'd1;
                if (index < len) begin
                    if (arr[index] < min1) begin
                        min2 <= min1;
                        min1 <= arr[index];
                    end else if (arr[index] < min2 && arr[index] != min1) begin
                        min2 <= arr[index];
                    end
                    index <= index + 4'd1;
                end else begin
                    if (len >= 2 && min2 != 8'd127) begin
                        result <= min2;
                        valid <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end
                    next_state = FINISH;
                end
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule