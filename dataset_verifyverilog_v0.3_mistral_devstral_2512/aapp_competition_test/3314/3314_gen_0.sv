module wheel_rotation(
    input [1:0] wheel0 [0:7],
    input [1:0] wheel1 [0:7],
    input [1:0] wheel2 [0:7],
    output reg signed [4:0] result
);

    reg [3:0] min_cost;
    reg [3:0] current_cost;
    reg [2:0] r0, r1, r2;
    reg [2:0] j;
    reg [1:0] val0, val1, val2;
    reg valid;
    reg found;

    always @(*) begin
        min_cost = 4'd15;
        found = 1'b0;

        for (r0 = 0; r0 < 8; r0 = r0 + 1) begin
            for (r1 = 0; r1 < 8; r1 = r1 + 1) begin
                for (r2 = 0; r2 < 8; r2 = r2 + 1) begin
                    current_cost = (r0 <= 4) ? r0 : (8 - r0);
                    current_cost = current_cost + ((r1 <= 4) ? r1 : (8 - r1));
                    current_cost = current_cost + ((r2 <= 4) ? r2 : (8 - r2));

                    valid = 1'b1;
                    for (j = 0; j < 8; j = j + 1) begin
                        val0 = wheel0[(j + r0) % 8];
                        val1 = wheel1[(j + r1) % 8];
                        val2 = wheel2[(j + r2) % 8];

                        if ((val0 == val1) || (val0 == val2) || (val1 == val2)) begin
                            valid = 1'b0;
                        end
                    end

                    if (valid && (current_cost < min_cost)) begin
                        min_cost = current_cost;
                        found = 1'b1;
                    end
                end
            end
        end

        if (found) begin
            result = min_cost;
        end else begin
            result = 5'd31;
        end
    end

endmodule