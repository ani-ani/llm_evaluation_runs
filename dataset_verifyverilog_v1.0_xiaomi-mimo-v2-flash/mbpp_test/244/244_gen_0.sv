module next_perfect_square(
    input clk,
    input rst_n,
    input start,
    input [15:0] N,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] CALC_ROOT   = 2'd1;
    localparam [1:0] CALC_SQUARE = 2'd2;
    localparam [1:0] DONE_STATE  = 2'd3;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] root_reg;
    reg [15:0] square_reg;
    reg [15:0] iter_count;
    reg [15:0] divisor;
    reg [15:0] dividend;
    reg [31:0] mult_temp;
    reg [15:0] mult_result;
    reg [15:0] n_reg;
    reg valid_root;
    reg [7:0] division_counter;
    reg division_done;
    reg [15:0] div_quotient;
    reg [15:0] div_remainder;
    reg [15:0] div_operand;

    // Division state
    localparam [1:0] DIV_IDLE = 2'd0;
    localparam [1:0] DIV_CALC = 2'd1;
    localparam [1:0] DIV_DONE = 2'd2;
    reg [1:0] div_state;

    // Sequential logic for state transition and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            root_reg <= 16'd0;
            square_reg <= 16'd0;
            iter_count <= 16'd0;
            n_reg <= 16'd0;
            valid_root <= 1'b0;
            div_state <= DIV_IDLE;
            division_counter <= 8'd0;
            division_done <= 1'b0;
            div_quotient <= 16'd0;
            div_remainder <= 16'd0;
            div_operand <= 16'd0;
            divisor <= 16'd0;
            dividend <= 16'd0;
            mult_temp <= 32'd0;
            mult_result <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= N;
                        if (N == 16'd0) begin
                            // Handle N=0 immediately
                            root_reg <= 16'd0;
                            valid_root <= 1'b1;
                            state <= CALC_SQUARE;
                        end else begin
                            // Initialize Newton-Raphson
                            root_reg <= N >> 1;
                            iter_count <= 16'd0;
                            valid_root <= 1'b0;
                            state <= CALC_ROOT;
                        end
                    end
                end

                CALC_ROOT: begin
                    if (iter_count < 16'd16) begin
                        // Newton-Raphson iteration: x_next = (x + N/x) / 2
                        // Step 1: Calculate N / root_reg
                        if (div_state == DIV_IDLE) begin
                            // Setup division
                            dividend <= n_reg;
                            divisor <= root_reg;
                            div_operand <= n_reg;
                            div_quotient <= 16'd0;
                            div_remainder <= n_reg;
                            division_counter <= 8'd0;
                            division_done <= 1'b0;
                            div_state <= DIV_CALC;
                        end else if (div_state == DIV_CALC) begin
                            // Integer division by repeated subtraction (16 cycles max)
                            if (division_counter < 8'd16) begin
                                if (div_remainder >= divisor) begin
                                    div_remainder <= div_remainder - divisor;
                                    div_quotient <= div_quotient + 16'd1;
                                end
                                division_counter <= division_counter + 8'd1;
                            end else begin
                                division_done <= 1'b1;
                                div_state <= DIV_DONE;
                            end
                        end else if (div_state == DIV_DONE) begin
                            // Step 2: x + N/x
                            // x is root_reg (16-bit), N/x is div_quotient (16-bit)
                            // Sum needs 17 bits, but we cap at 65535
                            if (root_reg + div_quotient > 16'hFFFF) begin
                                mult_temp <= 32'hFFFFFFFF;
                            end else begin
                                mult_temp <= {16'd0, root_reg + div_quotient};
                            end
                            
                            // Step 3: Divide by 2
                            mult_temp <= mult_temp >> 1;
                            
                            // Update root_reg
                            root_reg <= mult_temp[15:0];
                            
                            // Next iteration
                            iter_count <= iter_count + 16'd1;
                            div_state <= DIV_IDLE;
                        end
                    end else begin
                        // 16 iterations complete
                        valid_root <= 1'b1;
                        state <= CALC_SQUARE;
                    end
                end

                CALC_SQUARE: begin
                    // Calculate (root + 1)^2
                    // First check if root * root == N
                    // We already have root_reg, need to square it
                    mult_temp <= root_reg * root_reg;
                    square_reg <= mult_temp[15:0];
                    
                    if (square_reg == n_reg) begin
                        // Perfect square found, next is (root+1)^2
                        if (root_reg < 16'd255) begin
                            // Safe to compute (root+1)^2
                            mult_temp <= (root_reg + 16'd1) * (root_reg + 16'd1);
                            result <= mult_temp[15:0];
                        end else begin
                            // Clamp to 16-bit max if overflow
                            result <= 16'hFFFF;
                        end
                    end else begin
                        // Not perfect square, next perfect square is (root+1)^2
                        if (root_reg < 16'd255) begin
                            mult_temp <= (root_reg + 16'd1) * (root_reg + 16'd1);
                            result <= mult_temp[15:0];
                        end else begin
                            result <= 16'hFFFF;
                        end
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule