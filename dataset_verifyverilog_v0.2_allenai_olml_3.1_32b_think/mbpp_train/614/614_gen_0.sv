module cumulative_sum (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] tuple1_elem0, tuple1_elem1,
    input [7:0] tuple2_elem0, tuple2_elem1, tuple2_elem2,
    input [7:0] tuple3_elem0, tuple3_elem1,
    output reg [15:0] result,
    output reg done
);
localparam IDLE = 4'd0;
localparam ADD1 = 1, ADD2=2, ADD3=3, ADD4=4, ADD5=5, ADD6=6, ADD7=7;
localparam DONE = 8;

reg [3:0] state;
reg [15:0] sum;
reg new_done;

// Done with two registers
reg done_reg;
reg done_reg2;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        sum <= 16'd0;
        state <= IDLE;
        new_done <= 1'b0;
        done_reg <= 1'b0;
        done_reg2 <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    sum <= 16'd0;
                    state <= ADD1;
                end
                new_done <= 1'b0;
            end
            ADD1: begin
                sum <= sum + tuple1_elem0;
                state <= ADD2;
                new_done <= 1'b0;
            end
            ADD2: begin
                sum <= sum + tuple1_elem1;
                state <= ADD3;
                new_done <= 1'b0;
            end
            ADD3: begin
                sum <= sum + tuple2_elem0;
                state <= ADD4;
                new_done <= 1'b0;
            end
            ADD4: begin
                sum <= sum + tuple2_elem1;
                state <= ADD5;
                new_done <= 1'b0;
            end
            ADD5: begin
                sum <= sum + tuple2_elem2;
                state <= ADD6;
                new_done <= 1'b0;
            end
            ADD6: begin
                sum <= sum + tuple3_elem0;
                state <= ADD7;
                new_done <= 1'b0;
            end
            ADD7: begin
                sum <= sum + tuple3_elem1;
                state <= DONE;
                new_done <= 1'b0;
            end
            DONE: begin
                state <= IDLE;
                new_done <= 1'b1;
            end
            default: state <= IDLE; new_done <= 1'b0;
        endcase
    end
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        done_reg <= 1'b0;
        done_reg2 <= 1'b0;
    end else begin
        done_reg <= new_done;
        done_reg2 <= done_reg;
    end
end

assign result = sum;
assign done = done_reg2;

endmodule