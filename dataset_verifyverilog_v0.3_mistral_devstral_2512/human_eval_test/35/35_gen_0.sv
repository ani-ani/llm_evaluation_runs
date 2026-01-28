module max_element(
    input clk,
    input rst_n,
    input start,
    input [7:0] len,
    input [7:0] data [0:7],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [7:0] counter;
    reg [7:0] max_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            counter <= 8'd0;
            max_val <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        counter <= 8'd1;
                        max_val <= data[0];
                    end
                end

                PROCESSING: begin
                    if (counter < len) begin
                        if (data[counter] > max_val) begin
                            max_val <= data[counter];
                        end
                        counter <= counter + 8'd1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= max_val;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule