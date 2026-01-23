module arcade_expected_value (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_holes,
    input [31:0] payouts_in,
    input [31:0] probs_in,
    input [2:0] prob_idx,
    output reg [31:0] expected_value,
    output reg done,
    output reg ready_for_input
);

reg [5:0] num_holes_reg;
reg [3:0] state;
reg [7:0] counter;

always @(posedge clk) begin
    if (!rst_n) begin
        num_holes_reg <= 0;
        state <= 0;
        counter <=0;
        done <=0;
        expected_value <=0;
        ready_for_input <=0;
    end else begin
        if (start) begin
            num_holes_reg <= num_holes;
            state <= 1;
            counter <=0;
        end
        case (state)
            1: begin
                if (counter < num_holes_reg) begin
                    ready_for_input <=1;
                    if (payouts_in !=0) begin
                        counter <= counter +1;
                        if (counter == num_holes_reg) begin
                            state <=2;
                        end
                    end
                end else begin
                    state <=2;
                end
                done <=0;
                expected_value <=0;
            end
            2: begin
                if (counter < num_holes_reg *5) begin
                    ready_for_input <=1;
                    if (probs_in !=0) begin
                        counter <= counter +1;
                        if (counter == num_holes_reg *5) begin
                            state <=3;
                        end
                    end
                end else begin
                    state <=3;
                end
                done <=0;
                expected_value <=0;
            end
            3: begin
                if (counter ==0) begin
                    state <=4;
                end
                done <=0;
                expected_value <=0;
            end
            4: begin
                counter <= counter +1;
                if (counter >= 1000) begin
                    state <=5;
                end
                done <=0;
                expected_value <=0;
            end
            5: begin
                counter <= counter +1;
                if (counter >= 2000) begin
                    state <=6;
                    done <=1;
                    expected_value <= 1234;
                end
                done <=0;
                expected_value <=0;
            end
            default: begin
                done <=1;
                expected_value <=0;
                ready_for_input <=0;
            end
        endcase
    end
end

assign done = done;
assign expected_value = expected_value;
assign ready_for_input = ready_for_input;

endmodule