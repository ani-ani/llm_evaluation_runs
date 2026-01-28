module appleman_toastman(
    input clk,
    input rst_n,
    input start,
    input [2:0] len,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam MAX_N = 4;
    localparam DATA_WIDTH = 8;
    localparam RESULT_WIDTH = 16;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CAPTURE = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] arr_reg [0:3];
    reg [7:0] temp;
    reg [7:0] max_val;
    reg [15:0] sum;
    integer i, j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < MAX_N; i = i + 1) begin
                arr_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CAPTURE;
                end
            end

            CAPTURE: begin
                next_state = SORT;
            end

            SORT: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Capture input array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arr_reg[0] <= 8'd0;
            arr_reg[1] <= 8'd0;
            arr_reg[2] <= 8'd0;
            arr_reg[3] <= 8'd0;
        end else begin
            if (state == CAPTURE) begin
                arr_reg[0] <= arr_0;
                arr_reg[1] <= arr_1;
                arr_reg[2] <= arr_2;
                arr_reg[3] <= arr_3;
            end
        end
    end

    // Bubble sort
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state == SORT) begin
                cycle_count <= cycle_count + 8'd1;
                for (i = 0; i < len - 1; i = i + 1) begin
                    for (j = 0; j < len - i - 1; j = j + 1) begin
                        if (arr_reg[j] > arr_reg[j + 1]) begin
                            temp <= arr_reg[j];
                            arr_reg[j] <= arr_reg[j + 1];
                            arr_reg[j + 1] <= temp;
                        end
                    end
                end
            end
        end
    end

    // Compute weighted sum
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= 16'd0;
            max_val <= 8'd0;
        end else begin
            if (state == COMPUTE) begin
                sum <= 16'd0;
                max_val <= arr_reg[len - 1];
                for (i = 0; i < len; i = i + 1) begin
                    sum <= sum + (arr_reg[i] * (i + 2));
                end
                result <= sum - max_val;
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: done <= 1'b0;
                CAPTURE: done <= 1'b0;
                SORT: done <= 1'b0;
                COMPUTE: done <= 1'b0;
                FINISH: done <= 1'b1;
                default: done <= 1'b0;
            endcase
        end
    end

endmodule