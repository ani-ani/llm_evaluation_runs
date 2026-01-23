module power_segment_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [3:0] len,
    input signed [3:0] k,
    output reg [15:0] result,
    output reg done
);
    // Unpack array
    wire [7:0] arr [0:7];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;

    // State machine parameters
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_ADD = 3'd1;
    localparam [2:0] S_CHECK_POWER = 3'd2;
    localparam [2:0] S_CHECK_POWER_LOOP = 3'd3;
    localparam [2:0] S_CHECK_POWER_END = 3'd4;
    localparam [2:0] S_NEXT_J = 3'd5;
    localparam [2:0] S_NEXT_I = 3'd6;
    localparam [2:0] S_DONE = 3'd7;

    reg [2:0] state;
    reg [3:0] i, j;
    reg signed [15:0] sum;
    reg signed [15:0] p;
    reg found;
    reg [15:0] count;
    reg [15:0] p_abs;
    reg signed [15:0] next_p;
    reg [15:0] k_sign;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            i <= 4'd0;
            j <= 4'd0;
            sum <= 16'sd0;
            p <= 16'sd0;
            found <= 1'b0;
            count <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            p_abs <= 16'd0;
            next_p <= 16'sd0;
            k_sign <= 16'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 4'd0;
                        j <= 4'd0;
                        sum <= 16'sd0;
                        count <= 16'd0;
                        state <= S_ADD;
                    end
                end

                S_ADD: begin
                    if (j < len) begin
                        sum <= sum + $signed({8'd0, arr[j]});
                        state <= S_CHECK_POWER;
                    end else begin
                        state <= S_NEXT_I;
                    end
                end

                S_CHECK_POWER: begin
                    if (k == 4'sd1) begin
                        found <= (sum == 16'sd1);
                        state <= S_CHECK_POWER_END;
                    end else if (k == -4'sd1) begin
                        found <= (sum == 16'sd1) || (sum == -16'sd1);
                        state <= S_CHECK_POWER_END;
                    end else begin
                        p <= 16'sd1;
                        state <= S_CHECK_POWER_LOOP;
                    end
                end

                S_CHECK_POWER_LOOP: begin
                    // Calculate |p|
                    if (p[15]) begin
                        p_abs <= -p;
                    end else begin
                        p_abs <= p;
                    end
                    
                    // Check if |p| > 1016
                    if (p[15] ? (-p > 16'sd1016) : (p > 16'sd1016)) begin
                        found <= 1'b0;
                        state <= S_CHECK_POWER_END;
                    end else if (p == sum) begin
                        found <= 1'b1;
                        state <= S_CHECK_POWER_END;
                    end else begin
                        // Calculate p * k
                        if (k[3]) begin
                            // Negative k
                            next_p <= -p;
                        end else begin
                            // Positive k
                            next_p <= p;
                        end
                        state <= S_NEXT_I; // Temp state to update
                    end
                end

                S_CHECK_POWER_END: begin
                    if (found) begin
                        count <= count + 16'd1;
                    end
                    state <= S_NEXT_J;
                end

                S_NEXT_J: begin
                    j <= j + 4'd1;
                    state <= S_ADD;
                end

                S_NEXT_I: begin
                    // Update p if coming from S_CHECK_POWER_LOOP
                    if (state == S_CHECK_POWER_LOOP) begin
                        p <= next_p;
                        state <= S_CHECK_POWER_LOOP;
                    end else begin
                        i <= i + 4'd1;
                        if (i < len) begin
                            j <= i;
                            sum <= 16'sd0;
                            state <= S_ADD;
                        end else begin
                            state <= S_DONE;
                        end
                    end
                end

                S_DONE: begin
                    result <= count;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule