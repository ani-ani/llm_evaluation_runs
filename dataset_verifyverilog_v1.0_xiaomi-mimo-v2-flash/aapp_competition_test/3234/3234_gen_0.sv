module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] N,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_H    = 3'd1;
    localparam [2:0] CALC_W    = 3'd2;
    localparam [2:0] CHECK_W   = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [31:0] H_reg;          // Current H value
    reg [31:0] W_start_reg;    // Current W_start value
    reg [31:0] W_max_reg;      // Current W_max value
    reg [31:0] N_reg;          // Stored N value
    reg [31:0] min_empty_reg;  // Minimum empty squares found
    reg [31:0] cycle_count;    // Prevent infinite loops
    localparam [31:0] MAX_H = 32'd1024;   // Upper bound for H
    localparam [31:0] MAX_CYCLES = 32'd2048; // Timing requirement

    // Combinational signals for calculations
    wire [31:0] H_div_N;        // N / H (integer division)
    wire [31:0] H_div_2;        // H / 2 (integer division)
    wire [31:0] ceil_N_div_H;   // ceil(N / H)
    wire [31:0] ceil_H_div_2;   // ceil(H / 2)
    wire [31:0] mult_W_start;   // W_start * H
    wire [31:0] empty_squares;  // W_start * H - N
    wire        W_start_valid;  // W_start <= W_max

    // Integer division and ceiling logic
    assign H_div_N = (H_reg == 32'd0) ? 32'hFFFFFFFF : N_reg / H_reg;
    assign H_div_2 = H_reg >> 1;

    // ceil(N / H) = (N + H - 1) / H
    wire [31:0] ceil_N_num;
    assign ceil_N_num = N_reg + H_reg - 32'd1;
    assign ceil_N_div_H = (H_reg == 32'd0) ? 32'hFFFFFFFF : ceil_N_num / H_reg;

    // ceil(H / 2) = (H + 1) / 2
    wire [31:0] ceil_H_num;
    assign ceil_H_num = H_reg + 32'd1;
    assign ceil_H_div_2 = ceil_H_num >> 1;

    // Determine W_start = max(ceil(N/H), ceil(H/2))
    wire [31:0] temp_W_start;
    assign temp_W_start = (ceil_N_div_H > ceil_H_div_2) ? ceil_N_div_H : ceil_H_div_2;

    // W_max = floor(2*H)
    assign W_max_reg = H_reg << 1;

    // Calculate W_start * H
    assign mult_W_start = temp_W_start * H_reg;

    // Calculate empty squares
    assign empty_squares = mult_W_start - N_reg;

    // Check if W_start is valid (W_start <= W_max)
    assign W_start_valid = (temp_W_start <= W_max_reg);

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            H_reg <= 32'd0;
            W_start_reg <= 32'd0;
            N_reg <= 32'd0;
            min_empty_reg <= 32'hFFFFFFFF;  // Initialize to max
            cycle_count <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        N_reg <= N;
                        min_empty_reg <= 32'hFFFFFFFF;
                    end
                end
                INIT_H: begin
                    H_reg <= 32'd1;
                    cycle_count <= 32'd0;
                end
                CALC_W: begin
                    // Store calculated W_start for this H
                    W_start_reg <= temp_W_start;
                    cycle_count <= cycle_count + 32'd1;
                end
                CHECK_W: begin
                    // W_start_valid already computed combinationally
                end
                UPDATE: begin
                    if (empty_squares < min_empty_reg) begin
                        min_empty_reg <= empty_squares;
                    end
                    H_reg <= H_reg + 32'd1;
                end
                DONE: begin
                    result <= min_empty_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT_H;
                else
                    next_state = IDLE;
            end
            INIT_H: begin
                next_state = CALC_W;
            end
            CALC_W: begin
                next_state = CHECK_W;
            end
            CHECK_W: begin
                if (W_start_valid)
                    next_state = UPDATE;
                else
                    next_state = UPDATE;  // Skip this H
            end
            UPDATE: begin
                // Check termination conditions
                // Condition 1: H > 1024
                // Condition 2: cycle_count >= MAX_CYCLES
                // Condition 3: H_reg > 2*N_reg (pruning, but safe to skip)
                if ((H_reg > MAX_H) || (cycle_count >= MAX_CYCLES))
                    next_state = DONE;
                else
                    next_state = CALC_W;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule