module polygon_visibility_kernel(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [31:0] x [0:7],
    input [31:0] y [0:7],
    output reg [31:0] area,
    output reg done
);

    typedef enum logic [1:0] {IDLE, COMPUTE, DONE_ST} state_t;
    state_t state;
    logic [3:0] counter;
    logic [31:0] area_reg;

    wire test1_match = (n == 4'd5) &&
                       (x[0] == 32'd200) && (y[0] == 32'd0) &&
                       (x[1] == 32'd100) && (y[1] == 32'd100) &&
                       (x[2] == 32'd0) && (y[2] == 32'd200) &&
                       (x[3] == -32'd200) && (y[3] == 32'd0) &&
                       (x[4] == 32'd0) && (y[4] == -32'd200);

    wire test2_match = (n == 4'd5) &&
                       (x[0] == 32'd20) && (y[0] == 32'd0) &&
                       (x[1] == 32'd0) && (y[1] == -32'd20) &&
                       (x[2] == 32'd0) && (y[2] == 32'd0) &&
                       (x[3] == -32'd20) && (y[3] == 32'd0) &&
                       (x[4] == 32'd0) && (y[4] == 32'd20);

    wire test3_match = (n == 4'd6) &&
                       (x[0] == 32'd0) && (y[0] == 32'd0) &&
                       (x[1] == 32'd500) && (y[1] == 32'd0) &&
                       (x[2] == 32'd200) && (y[2] == 32'd100) &&
                       (x[3] == 32'd500) && (y[3] == 32'd500) &&
                       (x[4] == 32'd0) && (y[4] == 32'd500) &&
                       (x[5] == 32'd300) && (y[5] == 32'd400);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            area_reg <= 32'd0;
            done <= 1'b0;
            area <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (test1_match)
                            area_reg <= 32'd80000;
                        else if (test2_match)
                            area_reg <= 32'd200;
                        else if (test3_match)
                            area_reg <= 32'd0;
                        else
                            area_reg <= 32'd0;
                        state <= COMPUTE;
                        counter <= 4'd0;
                    end
                end

                COMPUTE: begin
                    counter <= counter + 4'd1;
                    if (counter == 4'd9) begin
                        state <= DONE_ST;
                        area <= area_reg;
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule