module PisaFSM(
    input clk,
    input rst_n,
    input start,
    input [3:0] alice_start,
    input [3:0] bob_start,
    input [3:0] left_0, input [3:0] left_1, input [3:0] left_2, input [3:0] left_3,
    input [3:0] left_4, input [3:0] left_5, input [3:0] left_6, input [3:0] left_7,
    input [3:0] left_8, input [3:0] left_9, input [3:0] left_10, input [3:0] left_11,
    input [3:0] left_12, input [3:0] left_13, input [3:0] left_14, input [3:0] left_15,
    input [3:0] right_0, input [3:0] right_1, input [3:0] right_2, input [3:0] right_3,
    input [3:0] right_4, input [3:0] right_5, input [3:0] right_6, input [3:0] right_7,
    input [3:0] right_8, input [3:0] right_9, input [3:0] right_10, input [3:0] right_11,
    input [3:0] right_12, input [3:0] right_13, input [3:0] right_14, input [3:0] right_15,
    input tower_0, input tower_1, input tower_2, input tower_3,
    input tower_4, input tower_5, input tower_6, input tower_7,
    input tower_8, input tower_9, input tower_10, input tower_11,
    input tower_12, input tower_13, input tower_14, input tower_15,
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [7:0] step_count;
    reg [3:0] alice_node;
    reg [3:0] bob_node;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            step_count <= 8'd0;
            alice_node <= 4'd0;
            bob_node <= 4'd0;
            found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                        step_count <= 8'd0;
                        alice_node <= alice_start;
                        bob_node <= bob_start;
                        found <= 1'b0;
                    end
                end

                SEARCH: begin
                    if (step_count == 8'd255) begin
                        result <= 16'hFFFF;
                        state <= DONE;
                    end else begin
                        case (step_count[0])
                            1'b0: begin
                                alice_node <= left_0;
                                bob_node <= right_0;
                            end
                            1'b1: begin
                                alice_node <= left_1;
                                bob_node <= right_1;
                            end
                            default: begin
                                alice_node <= left_2;
                                bob_node <= right_2;
                            end
                        endcase

                        if (tower_0 != tower_1) begin
                            found <= 1'b1;
                        end

                        if (found) begin
                            result[7:0] <= step_count;
                            result[15] <= 1'b1;
                            state <= DONE;
                        end else begin
                            step_count <= step_count + 8'd1;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule