module dragon (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [3:0] i;
    reg [7:0] dp0, dp1, dp2, dp3;
    reg [7:0] current_val;
    reg [7:0] max_val;

    // Function to read array element
    function [7:0] read_array;
        input [3:0] idx;
        begin
            case(idx)
                4'd0: read_array = arr_0;
                4'd1: read_array = arr_1;
                4'd2: read_array = arr_2;
                4'd3: read_array = arr_3;
                4'd4: read_array = arr_4;
                4'd5: read_array = arr_5;
                4'd6: read_array = arr_6;
                4'd7: read_array = arr_7;
                default: read_array = 8'd0;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            i <= 4'd0;
            dp0 <= 8'd0;
            dp1 <= 8'd0;
            dp2 <= 8'd0;
            dp3 <= 8'd0;
            current_val <= 8'd0;
            max_val <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    dp0 <= 8'd0;
                    dp1 <= 8'd0;
                    dp2 <= 8'd0;
                    dp3 <= 8'd0;
                    max_val <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (i < n) begin
                        current_val <= read_array(i);
                        if (read_array(i) == 8'd1) begin
                            dp0 <= dp0 + 8'd1;
                            if (dp1 > dp2) begin
                                dp2 <= dp1 + 8'd1;
                            end else begin
                                dp2 <= dp2 + 8'd1;
                            end
                        end else begin
                            if (dp0 > dp1) begin
                                dp1 <= dp0 + 8'd1;
                            end else begin
                                dp1 <= dp1 + 8'd1;
                            end
                            if (dp2 > dp3) begin
                                dp3 <= dp2 + 8'd1;
                            end else begin
                                dp3 <= dp3 + 8'd1;
                            end
                        end
                        i <= i + 8'd1;
                    end else begin
                        // Find max of dp0, dp1, dp2, dp3
                        max_val <= dp0;
                        if (dp1 > max_val) max_val <= dp1;
                        if (dp2 > max_val) max_val <= dp2;
                        if (dp3 > max_val) max_val <= dp3;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= max_val;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule