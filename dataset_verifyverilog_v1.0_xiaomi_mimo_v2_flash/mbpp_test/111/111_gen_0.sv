module find_common_elements (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr0_0, input wire [7:0] arr0_1, input wire [7:0] arr0_2, input wire [7:0] arr0_3,
    input wire [7:0] arr0_4, input wire [7:0] arr0_5, input wire [7:0] arr0_6, input wire [7:0] arr0_7,
    input wire [7:0] arr1_0, input wire [7:0] arr1_1, input wire [7:0] arr1_2, input wire [7:0] arr1_3,
    input wire [7:0] arr1_4, input wire [7:0] arr1_5, input wire [7:0] arr1_6, input wire [7:0] arr1_7,
    input wire [7:0] arr2_0, input wire [7:0] arr2_1, input wire [7:0] arr2_2, input wire [7:0] arr2_3,
    input wire [7:0] arr2_4, input wire [7:0] arr2_5, input wire [7:0] arr2_6, input wire [7:0] arr2_7,
    input wire [3:0] len0, input wire [3:0] len1, input wire [3:0] len2,
    output reg [63:0] result,
    output reg [3:0] result_count,
    output reg done
);

localparam [2:0] IDLE    = 3'd0;
localparam [2:0] CHECK   = 3'd1;
localparam [2:0] VALIDATE= 3'd2;
localparam [2:0] STORE   = 3'd3;
localparam [2:0] NEXT    = 3'd4;
localparam [2:0] COMPLETE= 3'd5;

reg [2:0] state, next_state;
reg [3:0] idx0;
reg [3:0] result_idx;
reg [7:0] candidate;
reg found1, found2;
reg [3:0] cycle_counter;

wire [7:0] arr0_data [0:7];
wire [7:0] arr1_data [0:7];
wire [7:0] arr2_data [0:7];

assign arr0_data[0] = arr0_0; assign arr0_data[1] = arr0_1; assign arr0_data[2] = arr0_2; assign arr0_data[3] = arr0_3;
assign arr0_data[4] = arr0_4; assign arr0_data[5] = arr0_5; assign arr0_data[6] = arr0_6; assign arr0_data[7] = arr0_7;
assign arr1_data[0] = arr1_0; assign arr1_data[1] = arr1_1; assign arr1_data[2] = arr1_2; assign arr1_data[3] = arr1_3;
assign arr1_data[4] = arr1_4; assign arr1_data[5] = arr1_5; assign arr1_data[6] = arr1_6; assign arr1_data[7] = arr1_7;
assign arr2_data[0] = arr2_0; assign arr2_data[1] = arr2_1; assign arr2_data[2] = arr2_2; assign arr2_data[3] = arr2_3;
assign arr2_data[4] = arr2_4; assign arr2_data[5] = arr2_5; assign arr2_data[6] = arr2_6; assign arr2_data[7] = arr2_7;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        idx0 <= 4'd0;
        result_idx <= 4'd0;
        result_count <= 4'd0;
        result <= 64'd0;
        done <= 1'b0;
        candidate <= 8'd0;
        found1 <= 1'b0;
        found2 <= 1'b0;
        cycle_counter <= 4'd0;
    end else begin
        state <= next_state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                idx0 <= 4'd0;
                result_idx <= 4'd0;
                result_count <= 4'd0;
                result <= 64'd0;
                cycle_counter <= 4'd0;
            end
            CHECK: begin
                if (idx0 < len0 && idx0 < 8'd8) begin
                    candidate <= arr0_data[idx0];
                end
                found1 <= 1'b0;
                found2 <= 1'b0;
            end
            VALIDATE: begin
                if (idx0 < len0 && idx0 < 8'd8) begin
                    if (idx0 < len1 && idx0 < 8'd8 && arr1_data[idx0] == candidate) begin
                        found1 <= 1'b1;
                    end
                    if (idx0 < len2 && idx0 < 8'd8 && arr2_data[idx0] == candidate) begin
                        found2 <= 1'b1;
                    end
                end
            end
            STORE: begin
                if (idx0 < len0 && idx0 < 8'd8 && found1 && found2 && result_idx < 4'd8) begin
                    result[result_idx*8 +: 8] <= candidate;
                    result_count <= result_count + 1'b1;
                    result_idx <= result_idx + 1'b1;
                end
            end
            NEXT: begin
                idx0 <= idx0 + 1'b1;
                cycle_counter <= cycle_counter + 1'b1;
            end
            COMPLETE: begin
                done <= 1'b1;
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = CHECK;
            end else begin
                next_state = IDLE;
            end
        end
        CHECK: begin
            if (idx0 < len0 && idx0 < 8'd8) begin
                next_state = VALIDATE;
            end else begin
                next_state = COMPLETE;
            end
        end
        VALIDATE: begin
            next_state = STORE;
        end
        STORE: begin
            next_state = NEXT;
        end
        NEXT: begin
            if (cycle_counter >= 4'd7 || idx0 >= 4'd7 || idx0 + 1'b1 >= len0) begin
                next_state = COMPLETE;
            end else begin
                next_state = CHECK;
            end
        end
        COMPLETE: begin
            if (!start) begin
                next_state = IDLE;
            end else begin
                next_state = COMPLETE;
            end
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule