module sum_even_fifth_power (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ITER_WIDTH = 8;
    localparam [ITER_WIDTH-1:0] MAX_N = 8'd256;
    localparam [3:0] MAX_CYCLES_PER_ITER = 4'd10;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_J = 3'd1;
    localparam [2:0] MULT_STAGE1 = 3'd2; // j*j
    localparam [2:0] MULT_STAGE2 = 3'd3; // j^2*j -> j^3
    localparam [2:0] MULT_STAGE3 = 3'd4; // j^3*j -> j^4
    localparam [2:0] MULT_STAGE4 = 3'd5; // j^4*j -> j^5
    localparam [2:0] ACCUM = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    // Registers
    reg [2:0] state, next_state;
    reg [ITER_WIDTH-1:0] i_reg; // Counter i
    reg [DATA_WIDTH-1:0] sum_reg; // Accumulator
    reg [DATA_WIDTH-1:0] j_reg; // 2*i (j)
    reg [DATA_WIDTH-1:0] prod_reg; // Intermediate product
    reg [3:0] cycle_cnt; // Cycle counter for pipeline depth
    reg [ITER_WIDTH-1:0] n_reg; // Store n

    // Combinational logic
    wire [DATA_WIDTH-1:0] j_wire = i_reg << 1; // 2*i
    wire [DATA_WIDTH-1:0] next_prod;
    wire [DATA_WIDTH-1:0] next_sum;
    wire loop_done = (i_reg > n_reg);

    // Multiplication logic (combinational for simulation, timing handled by state)
    // For synthesis, this is a large combinational block. 
    // To meet timing, pipelining is done via states MULT_STAGE1/2/3/4.
    // We assume synthesis tool inserts pipeline registers for timing.
    // If strictly sequential, we would break mult into more states. 
    // Here we simulate pipelining by using intermediate registers updated per state.
    
    // Stage 1: j * j
    wire [63:0] stage1_mult = j_reg * j_reg;
    // Stage 2: prev * j
    wire [63:0] stage2_mult = prod_reg * j_reg;
    // Stage 3: prev * j
    wire [63:0] stage3_mult = prod_reg * j_reg;
    // Stage 4: prev * j (Result j^5)
    wire [63:0] stage4_mult = prod_reg * j_reg;

    // Accumulate
    assign next_sum = sum_reg + prod_reg;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CALC_J;
                else next_state = IDLE;
            end
            CALC_J: next_state = MULT_STAGE1;
            MULT_STAGE1: next_state = MULT_STAGE2;
            MULT_STAGE2: next_state = MULT_STAGE3;
            MULT_STAGE3: next_state = MULT_STAGE4;
            MULT_STAGE4: next_state = ACCUM;
            ACCUM: begin
                if (loop_done) next_state = DONE_STATE;
                else next_state = CALC_J;
            end
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i_reg <= 8'd0;
            sum_reg <= 32'd0;
            j_reg <= 32'd0;
            prod_reg <= 32'd0;
            n_reg <= 8'd0;
            cycle_cnt <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i_reg <= 8'd1;
                        sum_reg <= 32'd0;
                        n_reg <= n;
                        cycle_cnt <= 4'd0;
                    end
                end

                CALC_J: begin
                    j_reg <= j_wire;
                    // Start first multiplication in next cycle
                end

                MULT_STAGE1: begin
                    // j * j -> prod_reg
                    prod_reg <= stage1_mult[DATA_WIDTH-1:0];
                end

                MULT_STAGE2: begin
                    // (j*j) * j -> prod_reg
                    prod_reg <= stage2_mult[DATA_WIDTH-1:0];
                end

                MULT_STAGE3: begin
                    // (j^3) * j -> prod_reg
                    prod_reg <= stage3_mult[DATA_WIDTH-1:0];
                end

                MULT_STAGE4: begin
                    // (j^4) * j -> prod_reg (j^5)
                    prod_reg <= stage4_mult[DATA_WIDTH-1:0];
                end

                ACCUM: begin
                    // Add j^5 to sum
                    sum_reg <= sum_reg + prod_reg;
                    // Increment i
                    i_reg <= i_reg + 8'd1;
                end

                DONE_STATE: begin
                    // Final result is stored in sum_reg
                    result <= sum_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule