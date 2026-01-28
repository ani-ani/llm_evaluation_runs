module phone_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [99:0] digits_in,
    input wire [6:0] n,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [6:0] count_8;
    reg [6:0] n_div_11;
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            count_8 <= 7'd0;
            n_div_11 <= 7'd0;
            cycle_count <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                    if (start) begin
                        state <= COUNT;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 7'd1;
                    count_8 <= 7'd0;
                    n_div_11 <= 7'd0;

                    // Count '8's in the first n bits
                    integer i;
                    for (i = 0; i < n; i = i + 1) begin
                        if (digits_in[i]) begin
                            count_8 <= count_8 + 7'd1;
                        end
                    end

                    // Compute n//11
                    n_div_11 <= n / 7'd11;

                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 7'd1;

                    // Compute min(count_8, n_div_11)
                    if (count_8 < n_div_11) begin
                        result <= count_8[3:0];
                    end else begin
                        result <= n_div_11[3:0];
                    end

                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule