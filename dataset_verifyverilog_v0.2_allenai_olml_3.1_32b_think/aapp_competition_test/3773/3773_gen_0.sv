module grundy_pile_solver (
   input clk,
   input rst_n,
   input start,
   input [31:0] A_i,
   input [31:0] K_i,
   output reg [31:0] grundy_out,
   output reg done
);
    reg [31:0] current_A;
    reg [31:0] current_K;
    reg [7:0] iteration_count;
    reg [2:0] state;
    always @(posedge clk) begin
        if (!rst_n) begin
            current_A <= 0;
            current_K <= 0;
            iteration_count <= 0;
            state <= 0;
            grundy_out <= 0;
            done <= 0;
        end else begin
            case (state)
                0: begin
                    if (start) begin
                        current_A <= A_i;
                        current_K <= K_i;
                        iteration_count <= 0;
                        state <= 1;
                    end
                end
                1: begin
                    if (current_A < current_K) begin
                        grundy_out <= 0;
                        done <= 1;
                        state <= 3;
                    end else if (current_A % current_K == 0) begin
                        grundy_out <= current_A / current_K;
                        done <= 1;
                        state <= 3;
                    end else if (iteration_count < 128) begin
                        iteration_count <= iteration_count + 1;
                        state <= 2;
                    end else begin
                        grundy_out <= 0;
                        done <= 1;
                        state <= 3;
                    end
                end
                2: begin
                    current_A <= current_A - ( ( ( (current_A / current_K) + 1 ) * ( (current_A % current_K) / ( (current_A / current_K) + 1 ) ) ) + 1 );
                    state <= 1;
                end
                3: begin
                end
            endcase
        end
    end
endmodule