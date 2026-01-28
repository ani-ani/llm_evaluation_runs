module QuotationAnalyzer(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] a [0:14],
    output reg [7:0] result_k,
    output reg no_quot,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] min_adjacent;
    reg [7:0] current_min;
    reg [3:0] i;
    reg [7:0] temp_min;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_k <= 8'd0;
            no_quot <= 1'b0;
            done <= 1'b0;
            min_adjacent <= 8'd0;
            current_min <= 8'd0;
            i <= 4'd0;
            temp_min <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    no_quot <= 1'b0;
                    result_k <= 8'd0;
                    if (start) begin
                        next_state <= CALC;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC: begin
                    // Compute min(a[0], a[n-1])
                    if (i == 4'd0) begin
                        temp_min <= (a[0] < a[n-1]) ? a[0] : a[n-1];
                        current_min <= temp_min;
                        i <= i + 4'd1;
                    end
                    // Compute min(a[i], a[i+1]) for i=1 to n-2
                    else if (i < n - 4'd1) begin
                        temp_min <= (a[i] < a[i+1]) ? a[i] : a[i+1];
                        if (temp_min < current_min) begin
                            current_min <= temp_min;
                        end
                        i <= i + 4'd1;
                    end
                    // Final comparison and decision
                    else begin
                        min_adjacent <= current_min;
                        if (min_adjacent >= 8'd1 && n >= 4'd1) begin
                            result_k <= min_adjacent;
                            no_quot <= 1'b0;
                        end else begin
                            result_k <= 8'd0;
                            no_quot <= 1'b1;
                        end
                        next_state <= DONE_STATE;
                        i <= 4'd0;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    no_quot <= 1'b0;
                    result_k <= 8'd0;
                end
            endcase
        end
    end

endmodule