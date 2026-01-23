module intersperse(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [7:0] delimiter,
    input [3:0] length,
    output reg [7:0] result,
    output reg valid,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] OUTPUT = 3'd1;
    localparam [2:0] DONE = 3'd2;

    reg [2:0] state;
    reg [3:0] counter;
    reg is_delimiter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            result <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            is_delimiter <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= OUTPUT;
                        counter <= 4'd0;
                        is_delimiter <= 1'b0;
                    end
                end

                OUTPUT: begin
                    if (is_delimiter) begin
                        result <= delimiter;
                        valid <= 1'b1;
                        is_delimiter <= 1'b0;
                        counter <= counter + 4'd1;
                    end else begin
                        if (counter < length) begin
                            result <= arr[counter];
                            valid <= 1'b1;
                            if (counter + 4'd1 < length) begin
                                is_delimiter <= 1'b1;
                            end else begin
                                state <= DONE;
                            end
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule