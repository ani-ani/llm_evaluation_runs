module triple_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] arr_0,
    input wire signed [15:0] arr_1,
    input wire signed [15:0] arr_2,
    input wire signed [15:0] arr_3,
    input wire signed [15:0] arr_4,
    input wire signed [15:0] arr_5,
    input wire signed [15:0] arr_6,
    input wire signed [15:0] arr_7,
    input wire signed [15:0] arr_8,
    input wire signed [15:0] arr_9,
    input wire signed [15:0] arr_10,
    input wire signed [15:0] arr_11,
    input wire signed [15:0] arr_12,
    input wire signed [15:0] arr_13,
    input wire signed [15:0] arr_14,
    input wire signed [15:0] arr_15,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i, j, k;
    reg [15:0] sum;
    reg distinct;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Array storage
    reg signed [15:0] arr [0:15];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            cycle_count <= 8'd0;
            arr[0] <= arr_0;
            arr[1] <= arr_1;
            arr[2] <= arr_2;
            arr[3] <= arr_3;
            arr[4] <= arr_4;
            arr[5] <= arr_5;
            arr[6] <= arr_6;
            arr[7] <= arr_7;
            arr[8] <= arr_8;
            arr[9] <= arr_9;
            arr[10] <= arr_10;
            arr[11] <= arr_11;
            arr[12] <= arr_12;
            arr[13] <= arr_13;
            arr[14] <= arr_14;
            arr[15] <= arr_15;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESSING;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    distinct = (i != j) & (i != k) & (j != k);
                    sum = arr[i] + arr[j];
                    if (distinct & (sum == arr[k])) begin
                        result <= result + 16'd1;
                    end
                    if (k == 4'd15) begin
                        if (j == 4'd15) begin
                            if (i == 4'd15) begin
                                next_state <= DONE;
                            end else begin
                                i <= i + 4'd1;
                                j <= 4'd0;
                                k <= 4'd0;
                                next_state <= PROCESSING;
                            end
                        end else begin
                            j <= j + 4'd1;
                            k <= 4'd0;
                            next_state <= PROCESSING;
                        end
                    end else begin
                        k <= k + 4'd1;
                        next_state <= PROCESSING;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    valid <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule