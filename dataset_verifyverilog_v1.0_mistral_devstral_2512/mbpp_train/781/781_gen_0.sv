module divisor_parity_check(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [15:0] divisor_count,
    output reg is_even,
    output reg done,
    output reg error
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] CALCULATING = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [15:0] i;
    reg [15:0] count_reg;
    reg [15:0] sqrt_n;
    reg [15:0] n_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Combinational logic
    wire [15:0] i_squared;
    assign i_squared = i * i;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            divisor_count <= 16'd0;
            is_even <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            i <= 16'd1;
            count_reg <= 16'd0;
            n_reg <= 16'd0;
            sqrt_n <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    divisor_count <= 16'd0;
                    i <= 16'd1;
                    count_reg <= 16'd0;
                    cycle_count <= 8'd0;

                    if (start) begin
                        if (n == 16'd0) begin
                            error <= 1'b1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else if (n == 16'd1) begin
                            divisor_count <= 16'd1;
                            is_even <= 1'b0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            n_reg <= n;
                            sqrt_n <= (n > 16'd16383) ? 16'd128 :
                                      (n > 16'd4095) ? 16'd64 :
                                      (n > 16'd1023) ? 16'd32 :
                                      (n > 16'd255) ? 16'd16 :
                                      (n > 16'd63) ? 16'd8 : 16'd4;
                            state <= COUNTING;
                        end
                    end
                end

                COUNTING: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (n_reg % i == 0) begin
                        if (n_reg / i == i) begin
                            count_reg <= count_reg + 16'd1;
                        end else begin
                            count_reg <= count_reg + 16'd2;
                        end
                    end

                    i <= i + 16'd1;

                    if (i >= sqrt_n || i > 16'd256 || cycle_count >= MAX_CYCLES) begin
                        state <= CALCULATING;
                    end else begin
                        state <= COUNTING;
                    end
                end

                CALCULATING: begin
                    divisor_count <= count_reg;
                    is_even <= (count_reg % 2 == 0);
                    done <= 1'b1;
                    state <= COMPLETE;
                end

                COMPLETE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule