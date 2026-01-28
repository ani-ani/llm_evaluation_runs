module max_sum_dp (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // FSM states
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] COMPUTE  = 3'd1;
    localparam [2:0] COMPLETE = 3'd2;

    reg [2:0] state;
    reg [7:0] i;
    reg [15:0] res [0:60];
    reg [15:0] sum_terms;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            i <= 8'd0;
            sum_terms <= 16'd0;
            cycle_count <= 8'd0;
            for (idx = 0; idx <= 60; idx = idx + 1) begin
                res[idx] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    res[0] <= 16'd0;
                    res[1] <= 16'd1;
                    if (start) begin
                        if (n <= 8'd1) begin
                            if (n == 8'd0)
                                result <= 16'd0;
                            else
                                result <= 16'd1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            i <= 8'd2;
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    sum_terms <= res[i >> 1] + res[i / 3] + res[i / 4] + res[i / 5];
                    if ((res[i >> 1] + res[i / 3] + res[i / 4] + res[i / 5]) > i)
                        res[i] <= res[i >> 1] + res[i / 3] + res[i / 4] + res[i / 5];
                    else
                        res[i] <= {8'd0, i};
                    
                    if (i == n || cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end else begin
                        i <= i + 8'd1;
                    end
                end

                COMPLETE: begin
                    result <= res[n];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule