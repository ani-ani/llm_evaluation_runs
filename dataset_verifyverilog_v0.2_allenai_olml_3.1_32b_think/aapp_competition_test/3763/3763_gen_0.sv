module restaurant_visitor_expected (input clk, input rst_n, // active low, input start, input [2:0] n, input [5:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7, output reg [31:0] result, output reg done);
reg [2:0] n_value;
reg [5:0] p_value;
reg [5:0] a0, a1, a2;
reg [31:0] total_count;
reg [3:0] perm_count;
reg [31:0] factorial;
reg [31:0] final_result;
reg [3:0] state, next_state;
localparam IDLE = 4'd0, CALC = 4'd1, DONE = 4'd2;
always @(posedge clk) begin
    if (!rst_n) begin
        n_value <= n;
p_value <= p;
a0 <= a_0;
a1 <= a_1;
a2 <= a_2;
total_count <= 32'd0;
perm_count <= 4'd0;
factorial <= 6;
final_result <= 32'd0;
state <= IDLE;
done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start && n_value == 3) begin
                    next_state <= CALC;
                end
                state <= next_state;
                done <= 1'b0;
            end
            CALC: begin
                if (perm_count < 6) begin
                    reg [31:0] count;
                    count <= 32'd0;
                    case (perm_count)
                        0: begin
                            if (p_value >= a0) count <= count + 1;
                            if (p_value >= a0 + a1) count <= count + 1;
                            if (p_value >= a0 + a1 + a2) count <= count + 1;
                        end
                        1: begin
                            if (p_value >= a0) count <= count + 1;
                            if (p_value >= a0 + a2) count <= count + 1;
                            if (p_value >= a0 + a2 + a1) count <= count + 1;
                        end
                        2: begin
                            if (p_value >= a1) count <= count + 1;
                            if (p_value >= a1 + a0) count <= count + 1;
                            if (p_value >= a1 + a0 + a2) count <= count + 1;
                        end
                        3: begin
                            if (p_value >= a1) count <= count + 1;
                            if (p_value >= a1 + a2) count <= count + 1;
                            if (p_value >= a1 + a2 + a0) count <= count + 1;
                        end
                        4: begin
                            if (p_value >= a2) count <= count + 1;
                            if (p_value >= a2 + a0) count <= count + 1;
                            if (p_value >= a2 + a0 + a1) count <= count + 1;
                        end
                        5: begin
                            if (p_value >= a2) count <= count + 1;
                            if (p_value >= a2 + a1) count <= count + 1;
                            if (p_value >= a2 + a1 + a0) count <= count + 1;
                        end
                    endcase
                    total_count <= total_count + count;
                    perm_count <= perm_count + 1;
                    next_state <= (perm_count == 6) ? DONE : CALC;
                end else begin
                    next_state <= DONE;
                end
                state <= next_state;
                done <= (state == DONE);
            end
            DONE: begin
                final_result <= (total_count * 65536) / 6;
                result <= final_result;
                state <= DONE;
            end
        endcase
    end
endmodule