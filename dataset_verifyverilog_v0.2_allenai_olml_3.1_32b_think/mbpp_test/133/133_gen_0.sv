module sum_negative (
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [2:0] index,
    input reg [7:0] data_in,
    output reg [11:0] result,
    output reg done
);

reg [11:0] sum;
reg [2:0] count;
reg [1:0] state, next_state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        sum <= 12'd0;
        count <= 3'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;

        if (next_state == 2'b01) begin
            sum <= 12'd0;
            count <= 3'b0;
        end

        if (state == 2'b01) begin
            if (data_in[7])
                sum <= sum + (signed)data_in;
            count <= count + 1;
        end

        result <= sum;

        next_state = state;

        case (state)
            2'b00: begin
                if (start)
                    next_state = 2'b01;
            end
            2'b01: begin
                if (count == 3'b111)
                    next_state = 2'b10;
            end
            2'b10: begin
                next_state = 2'b00;
            end
        endcase

        done <= (state == 2'b10);
    end
end

endmodule