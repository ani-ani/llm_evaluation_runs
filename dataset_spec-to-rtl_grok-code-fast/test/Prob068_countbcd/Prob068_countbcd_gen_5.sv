module TopModule(input clk, input reset, output [2:0] ena, output [15:0] q);

    reg [3:0] units, tens, hundreds, thousands;
    assign q = {thousands, hundreds, tens, units};

    always @(posedge clk) begin
        if (reset == 1) begin
            units <= 4'd0;
            tens <= 4'd0;
            hundreds <= 4'd0;
            thousands <= 4'd0;
        end else begin
            // calculate carries

            logic carry1 = (units == 4'd9);
            logic carry2 = (tens == 4'd9) && carry1;
            logic carry3 = (hundreds == 4'd9) && carry2;

            // update units
            if (carry1) begin
                units <= 4'd0;
            end else begin
                units <= units + 1;
            end

            // update tens
            if (carry1) begin
                if (carry2) begin
                    tens <= 4'd0;
                end else begin
                    tens <= tens + 1;
                end
            end

            // update hundreds
            if (carry2) begin
                if (carry3) begin
                    hundreds <= 4'd0;
                end else begin
                    hundreds <= hundreds + 1;
                end
            end

            // update thousands
            if (carry3) begin
                if (thousands == 4'd9) begin
                    thousands <= 4'd0;
                end else begin
                    thousands <= thousands + 1;
                end
            end

            // enables
            ena[0] <= carry1;
            ena[1] <= carry2;
            ena[2] <= carry3;
        end
    end
endmodule