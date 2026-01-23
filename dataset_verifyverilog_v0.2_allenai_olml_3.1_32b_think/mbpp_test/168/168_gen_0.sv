module frequency_counter (input clk, input rst_n, input start, input [7:0] target, input [7:0] list [0:7], output reg [3:0] count, output reg done);

localparam IDLE = 2'd0;
localparam SETUP = 2'd1;
localparam PROCESSING = 2'd2;
localparam DONE = 2'd3;

reg [2:0] state;
reg [3:0] count;
reg [3:0] index;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        count <= 4'd0;
        index <= 4'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= SETUP;
                    count <= 4'd0;
                    index <= 4'd0;
                end
            end
            SETUP: begin
                state <= PROCESSING;
            end
            PROCESSING: begin
                if (list[index] == target)
                    count <= count + 1;
                index <= index + 1;
                if (index == 4'd8) begin
                    state <= DONE;
                    done <= 1'b1;
                end else begin
                    state <= PROCESSING;
                end
            end
            DONE: state <= DONE;
        endcase
    end
end

endmodule