module evasion_probability #(
    parameter R_WIDTH = 8,
    parameter C_WIDTH = 8,
    parameter K_WIDTH = 8
) (
    input clk,
    input rst_n,
    input start,
    input [R_WIDTH-1:0] R,
    input [C_WIDTH-1:0] C,
    input [K_WIDTH-1:0] K,
    output reg [63:0] numerator,
    output reg [63:0] denominator,
    output reg valid
);

    // State machine states
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_S    = 3'd1;
    localparam [2:0] CALC_M    = 3'd2;
    localparam [2:0] DONE      = 3'd3;
    localparam [2:0] ERROR     = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [63:0] S_reg;
    reg [63:0] M_reg;
    reg [R_WIDTH:0] i_reg;  // +1 bit for range checking
    reg [C_WIDTH:0] j_reg;  // +1 bit for range checking
    reg [63:0] term_reg;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Combinational calculations
    reg [R_WIDTH:0] dr;
    reg [C_WIDTH:0] dc;
    reg [63:0] term_calc;
    reg [63:0] product_R_C;
    reg [63:0] M_squared;

    always @(*) begin
        // Calculate dr and dc values
        dr = i_reg;
        dc = j_reg;

        // Calculate term: (R - dr) * (C - dc)
        if (dr <= R && dc <= C) begin
            term_calc = (R - dr[R_WIDTH-1:0]) * (C - dc[C_WIDTH-1:0]);
        end else begin
            term_calc = 64'd0;
        end

        // Calculate M = R * C
        product_R_C = R * C;

        // Calculate M^2
        M_squared = M_reg * M_reg;
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_S;
                end else begin
                    next_state = IDLE;
                end
            end

            CALC_S: begin
                // Continue if i <= R and i <= K
                if (i_reg[R_WIDTH] == 1'b0 && i_reg <= K) begin
                    next_state = CALC_S;
                end else begin
                    next_state = CALC_M;
                end
            end

            CALC_M: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            numerator <= 64'd0;
            denominator <= 64'd0;
            S_reg <= 64'd0;
            M_reg <= 64'd0;
            i_reg <= {(R_WIDTH+1){1'b0}};
            j_reg <= {(C_WIDTH+1){1'b0}};
            term_reg <= 64'd0;
            cycle_counter <= 8'd0;
        end else begin
            cycle_counter <= cycle_counter + 8'd1;
            
            case (next_state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        S_reg <= 64'd0;
                        M_reg <= 64'd0;
                        i_reg <= {(R_WIDTH+1){1'b0}};
                        j_reg <= {(C_WIDTH+1){1'b0}};
                        state <= CALC_S;
                    end else begin
                        state <= IDLE;
                    end
                end

                CALC_S: begin
                    if (j_reg <= C && i_reg + j_reg <= K) begin
                        // Calculate term
                        term_reg <= term_calc;
                        
                        // Add to S with appropriate multiplier
                        if (i_reg == 0 && j_reg == 0) begin
                            S_reg <= S_reg + term_calc;
                        end else if (i_reg == 0 || j_reg == 0) begin
                            S_reg <= S_reg + (term_calc << 1);  // * 2
                        end else begin
                            S_reg <= S_reg + (term_calc << 2);  // * 4
                        end
                        
                        // Increment j
                        j_reg <= j_reg + 1;
                    end else begin
                        // Reset j and increment i
                        j_reg <= 0;
                        i_reg <= i_reg + 1;
                    end
                    state <= CALC_S;
                    
                    // Exit condition
                    if (i_reg[R_WIDTH] == 1'b1 || i_reg > K) begin
                        state <= CALC_M;
                    end
                    
                    // Prevent infinite loop
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= ERROR;
                    end
                end

                CALC_M: begin
                    M_reg <= product_R_C;
                    state <= DONE;
                end

                DONE: begin
                    numerator <= M_squared - S_reg;
                    denominator <= M_squared;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                ERROR: begin
                    // Error state - set outputs to zero and valid to 0
                    numerator <= 64'd0;
                    denominator <= 64'd0;
                    valid <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    numerator <= 64'd0;
                    denominator <= 64'd0;
                end
            endcase
        end
    end

endmodule