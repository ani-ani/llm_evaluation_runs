module fibfib_calculator(
    input clk,
    input rst_n,
    input [3:0] n,
    input start,
    output reg [11:0] result,
    output reg done
);

    reg [11:0] a, b, c;
    reg [3:0] counter;
    reg computing;
    reg [3:0] target_n;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a <= 12'd0;
            b <= 12'd0;
            c <= 12'd0;
            counter <= 4'd0;
            computing <= 1'b0;
            result <= 12'd0;
            done <= 1'b0;
            target_n <= 4'd0;
        end else begin
            if (start && !computing) begin
                computing <= 1'b1;
                counter <= 4'd0;
                target_n <= n;
                done <= 1'b0;
                a <= 12'd0;
                b <= 12'd0;
                c <= 12'd1;
            end else if (computing) begin
                if (counter < target_n) begin
                    if (counter >= 4'd2) begin
                        a <= b;
                        b <= c;
                        c <= a + b + c;
                    end
                    counter <= counter + 4'd1;
                end else begin
                    if (target_n == 4'd0) begin
                        result <= a;
                    end else if (target_n == 4'd1) begin
                        result <= b;
                    end else begin
                        result <= c;
                    end
                    done <= 1'b1;
                    computing <= 1'b0;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule