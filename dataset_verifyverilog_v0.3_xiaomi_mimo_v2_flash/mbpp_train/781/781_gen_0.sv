module divisor_parity_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [15:0] divisor_count,
    output reg is_even,
    output reg done,
    output reg error
);

    parameter MAX_ITER = 16'd256;

    parameter [2:0] IDLE = 3'd0;
    parameter [2:0] COUNTING = 3'd1;
    parameter [2:0] CALCULATING = 3'd2;
    parameter [2:0] COMPLETE = 3'd3;

    reg [2:0] state;
    reg [15:0] i;
    reg [15:0] count_reg;
    reg [15:0] n_reg;
    reg [15:0] sqrt_n;

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
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    divisor_count <= 16'd0;
                    i <= 16'd1;
                    count_reg <= 16'd0;
                    
                    if (start) begin
                        if (n == 16'd0) begin
                            error <= 1'b1;
                            done <= 1'b1;
                        end else if (n == 16'd1) begin
                            divisor_count <= 16'd1;
                            is_even <= 1'b0;
                            done <= 1'b1;
                        end else begin
                            n_reg <= n;
                            if (n > 16'd16383)
                                sqrt_n <= 16'd128;
                            else if (n > 16'd4095)
                                sqrt_n <= 16'd64;
                            else if (n > 16'd1023)
                                sqrt_n <= 16'd32;
                            else if (n > 16'd255)
                                sqrt_n <= 16'd16;
                            else if (n > 16'd63)
                                sqrt_n <= 16'd8;
                            else
                                sqrt_n <= 16'd4;
                            state <= COUNTING;
                        end
                    end
                end
                
                COUNTING: begin
                    if (n_reg % i == 0) begin
                        if (n_reg / i == i)
                            count_reg <= count_reg + 16'd1;
                        else
                            count_reg <= count_reg + 16'd2;
                    end
                    
                    i <= i + 16'd1;
                    
                    if (i >= sqrt_n || i > MAX_ITER)
                        state <= CALCULATING;
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