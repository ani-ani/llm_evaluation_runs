module digit_sum_to_binary(input clk, input rst_n, // active-low reset input start, input [7:0] N, output reg [3:0] result, output reg done);
localparam IDLE = 2'd0,
        CALCULATE_SUM = 2'd1,
        CONVERT_BINARY = 2'd2,
        DONE = 2'd3;
reg [1:0] state,
    calc_counter, // 2 bits: counts 2,1,0 → 3 cycles
    convert_counter; // 2 bits: counts 3 (11), 2(10),1(01),0(00) → 4 cycles;

reg [3:0] sum_value;
reg [3:0] result_value;

// Default assignments
always @(*) begin
    state <= IDLE;
    calc_counter <= 0;
    convert_counter <=0;
    sum_value <=0;
    result_value <=0;
    done <=0;
end

// State machine and control logic
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        calc_counter <=0;
        convert_counter <=0;
        sum_value <=0;
        result_value <=0;
        done <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    // Calculate digit sum
                    sum_value = N / 100 + ((N % 100) / 10) + (N % 10);
                    state <= CALCULATE_SUM;
                    calc_counter <= 2; // 3 cycles
                end
            end
            CALCULATE_SUM: begin
                result_value = sum_value; // Capture result
                if (calc_counter == 0) begin
                    state <= CONVERT_BINARY;
                    convert_counter <= 3; // 4 cycles
                end else begin
                    calc_counter <= calc_counter - 1;
                end
            end
            CONVERT_BINARY: begin
                if (convert_counter == 0) begin
                    state <= DONE;
                end else begin
                    convert_counter <= convert_counter - 1;
                end
            end
            DONE: begin
                // Remain in DONE state
            end
        endcase
    end
end

// Output assignments
assign result = result_value;
assign done = (state == DONE);

endmodule