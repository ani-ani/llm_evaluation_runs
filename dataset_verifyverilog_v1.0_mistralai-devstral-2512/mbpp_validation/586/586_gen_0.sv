module array_rotator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] n,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] ROTATE  = 3'd2;
    localparam [2:0] FINISH  = 3'd3;

    reg [2:0] state;
    reg [7:0] temp [0:7];
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 4'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load input array into temp buffer
                    temp[0] <= arr_0;
                    temp[1] <= arr_1;
                    temp[2] <= arr_2;
                    temp[3] <= arr_3;
                    temp[4] <= arr_4;
                    temp[5] <= arr_5;
                    temp[6] <= arr_6;
                    temp[7] <= arr_7;
                    state <= ROTATE;
                end

                ROTATE: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Perform rotation: result = arr[n:] + arr[:n]
                    // Handle each possible n value (0-7)
                    case (n)
                        4'd0: begin
                            result_0 <= temp[0];
                            result_1 <= temp[1];
                            result_2 <= temp[2];
                            result_3 <= temp[3];
                            result_4 <= temp[4];
                            result_5 <= temp[5];
                            result_6 <= temp[6];
                            result_7 <= temp[7];
                        end
                        4'd1: begin
                            result_0 <= temp[1];
                            result_1 <= temp[2];
                            result_2 <= temp[3];
                            result_3 <= temp[4];
                            result_4 <= temp[5];
                            result_5 <= temp[6];
                            result_6 <= temp[7];
                            result_7 <= temp[0];
                        end
                        4'd2: begin
                            result_0 <= temp[2];
                            result_1 <= temp[3];
                            result_2 <= temp[4];
                            result_3 <= temp[5];
                            result_4 <= temp[6];
                            result_5 <= temp[7];
                            result_6 <= temp[0];
                            result_7 <= temp[1];
                        end
                        4'd3: begin
                            result_0 <= temp[3];
                            result_1 <= temp[4];
                            result_2 <= temp[5];
                            result_3 <= temp[6];
                            result_4 <= temp[7];
                            result_5 <= temp[0];
                            result_6 <= temp[1];
                            result_7 <= temp[2];
                        end
                        4'd4: begin
                            result_0 <= temp[4];
                            result_1 <= temp[5];
                            result_2 <= temp[6];
                            result_3 <= temp[7];
                            result_4 <= temp[0];
                            result_5 <= temp[1];
                            result_6 <= temp[2];
                            result_7 <= temp[3];
                        end
                        4'd5: begin
                            result_0 <= temp[5];
                            result_1 <= temp[6];
                            result_2 <= temp[7];
                            result_3 <= temp[0];
                            result_4 <= temp[1];
                            result_5 <= temp[2];
                            result_6 <= temp[3];
                            result_7 <= temp[4];
                        end
                        4'd6: begin
                            result_0 <= temp[6];
                            result_1 <= temp[7];
                            result_2 <= temp[0];
                            result_3 <= temp[1];
                            result_4 <= temp[2];
                            result_5 <= temp[3];
                            result_6 <= temp[4];
                            result_7 <= temp[5];
                        end
                        4'd7: begin
                            result_0 <= temp[7];
                            result_1 <= temp[0];
                            result_2 <= temp[1];
                            result_3 <= temp[2];
                            result_4 <= temp[3];
                            result_5 <= temp[4];
                            result_6 <= temp[5];
                            result_7 <= temp[6];
                        end
                        default: begin
                            result_0 <= temp[0];
                            result_1 <= temp[1];
                            result_2 <= temp[2];
                            result_3 <= temp[3];
                            result_4 <= temp[4];
                            result_5 <= temp[5];
                            result_6 <= temp[6];
                            result_7 <= temp[7];
                        end
                    endcase

                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule