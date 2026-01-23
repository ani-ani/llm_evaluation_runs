module snake_exhibition (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] s,
    output reg [3:0] result,
    output reg done
);
reg [2:0] state;
reg [2:0] counter;
reg [3:0] total_result;
reg [2:0] captured_n;
assign result = total_result;
localparam IDLE = 3'b000;
localparam PROCESSING = 3'b001;
localparam DONE = 3'b010;
always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 0;
        total_result <= 0;
        captured_n <= 0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    captured_n <= n;
                    state <= PROCESSING;
                    counter <= 0;
                    total_result <= 0;
                end
                else begin
                    state <= IDLE;
                end
            end
            PROCESSING: begin
                if (counter < captured_n) begin
                    integer i;
                    i = counter;
                    bit belt_out;
                    belt_out = s[i];
                    bit belt_in;
                    if (captured_n == 1) begin
                        belt_in = s[0];
                    end else begin
                        if (i == 0) begin
                            belt_in = s[captured_n - 1];
                        end else begin
                            belt_in = s[i-1];
                        end
                    end
                    bit returnable;
                    returnable = (belt_out == 0) || (belt_in == 0) || ((belt_in == 1) && (belt_out == 1));
                    if (returnable)
                        total_result <= total_result + 1;
                    else
                        total_result <= total_result;
                    counter <= counter + 1;
                    state <= PROCESSING;
                end else begin
                    state <= DONE;
                    done <= 1;
                end
            end
            DONE: begin
                state <= DONE;
                done <= 1;
            end
        endcase
    end
end
endmodule