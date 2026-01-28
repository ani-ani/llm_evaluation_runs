module prime_factorization (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] factors [0:15],
    output reg [3:0] valid_len,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] INIT        = 4'd1;
    localparam [3:0] CHECK_I     = 4'd2;
    localparam [3:0] CHECK_DIV   = 4'd3;
    localparam [3:0] DIVISIBLE   = 4'd4;
    localparam [3:0] INCREMENT_I = 4'd5;
    localparam [3:0] CHECK_N     = 4'd6;
    localparam [3:0] APPEND_N    = 4'd7;
    localparam [3:0] FINISH      = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [7:0] current_n;           // Current value being factored
    reg [7:0] i_reg;               // Current divisor
    reg [3:0] factor_count;        // Number of factors found
    reg [7:0] remainder;           // For division operation
    reg [7:0] quotient;            // For division operation
    reg [7:0] counter;             // For division loop
    reg [2:0] div_state;           // Division FSM state
    reg performing_division;       // Flag for division in progress
    reg [7:0] div_i_save;          // Save i during division
    reg [2:0] cycle_count;         // Prevent infinite loops
    localparam [2:0] MAX_CYCLES = 3'd6;

    // Division FSM states
    localparam [2:0] DIV_IDLE     = 3'd0;
    localparam [2:0] DIV_START    = 3'd1;
    localparam [2:0] DIV_LOOP     = 3'd2;
    localparam [2:0] DIV_DONE     = 3'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            next_state <= IDLE;
            current_n <= 8'd0;
            i_reg <= 8'd0;
            factor_count <= 4'd0;
            remainder <= 8'd0;
            quotient <= 8'd0;
            counter <= 8'd0;
            div_state <= DIV_IDLE;
            performing_division <= 1'b0;
            div_i_save <= 8'd0;
            cycle_count <= 3'd0;
            done <= 1'b0;
            valid_len <= 4'd0;
            // Initialize factors array
            factors[0] <= 8'd0; factors[1] <= 8'd0; factors[2] <= 8'd0; factors[3] <= 8'd0;
            factors[4] <= 8'd0; factors[5] <= 8'd0; factors[6] <= 8'd0; factors[7] <= 8'd0;
            factors[8] <= 8'd0; factors[9] <= 8'd0; factors[10] <= 8'd0; factors[11] <= 8'd0;
            factors[12] <= 8'd0; factors[13] <= 8'd0; factors[14] <= 8'd0; factors[15] <= 8'd0;
        end else begin
            // Main FSM
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    current_n <= n;
                    i_reg <= 8'd2;
                    factor_count <= 4'd0;
                    cycle_count <= 3'd0;
                    // Clear factors array
                    factors[0] <= 8'd0; factors[1] <= 8'd0; factors[2] <= 8'd0; factors[3] <= 8'd0;
                    factors[4] <= 8'd0; factors[5] <= 8'd0; factors[6] <= 8'd0; factors[7] <= 8'd0;
                    factors[8] <= 8'd0; factors[9] <= 8'd0; factors[10] <= 8'd0; factors[11] <= 8'd0;
                    factors[12] <= 8'd0; factors[13] <= 8'd0; factors[14] <= 8'd0; factors[15] <= 8'd0;
                    valid_len <= 4'd0;
                    performing_division <= 1'b0;
                    if (current_n == 8'd1) begin
                        state <= FINISH;
                    end else begin
                        state <= CHECK_I;
                    end
                end
                
                CHECK_I: begin
                    if (current_n < (i_reg * i_reg)) begin
                        state <= CHECK_N;
                    end else if (i_reg > current_n) begin
                        state <= CHECK_N;
                    end else begin
                        state <= CHECK_DIV;
                    end
                end
                
                CHECK_DIV: begin
                    if (!performing_division) begin
                        // Start division: current_n % i_reg
                        performing_division <= 1'b1;
                        div_i_save <= i_reg;
                        div_state <= DIV_START;
                        cycle_count <= 3'd0;
                    end
                    
                    // Division FSM
                    case (div_state)
                        DIV_START: begin
                            remainder <= current_n;
                            quotient <= 8'd0;
                            counter <= 8'd0;
                            div_state <= DIV_LOOP;
                        end
                        
                        DIV_LOOP: begin
                            if (remainder >= div_i_save && cycle_count < MAX_CYCLES) begin
                                remainder <= remainder - div_i_save;
                                quotient <= quotient + 8'd1;
                                cycle_count <= cycle_count + 3'd1;
                            end else begin
                                div_state <= DIV_DONE;
                            end
                        end
                        
                        DIV_DONE: begin
                            performing_division <= 1'b0;
                            if (remainder == 8'd0) begin
                                state <= DIVISIBLE;
                            end else begin
                                state <= INCREMENT_I;
                            end
                        end
                        
                        default: begin
                            div_state <= DIV_IDLE;
                            performing_division <= 1'b0;
                        end
                    endcase
                end
                
                DIVISIBLE: begin
                    // i_reg is a factor
                    if (factor_count < 4'd16) begin
                        factors[factor_count] <= i_reg;
                        factor_count <= factor_count + 4'd1;
                        current_n <= quotient;
                        // Continue checking same i
                        state <= CHECK_I;
                    end else begin
                        // Too many factors, should not happen for 8-bit
                        state <= FINISH;
                    end
                end
                \                INCREMENT_I: begin
                    i_reg <= i_reg + 8'd1;
                    state <= CHECK_I;
                end
                
                CHECK_N: begin
                    if (current_n > 8'd1) begin
                        state <= APPEND_N;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                APPEND_N: begin
                    if (factor_count < 4'd16) begin
                        factors[factor_count] <= current_n;
                        factor_count <= factor_count + 4'd1;
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    valid_len <= factor_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule