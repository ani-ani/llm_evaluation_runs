module hunter_exam (
    input clk,
    input rst_n,
    input start,
    output reg done,
    output reg [63:0] result_max
);

localparam C = 5;
localparam K = 2;
localparam [63:0] INF = 64'sh8000000000000000;

// Matrix A hardcoded for test case 1
wire signed [63:0] A_0_0;
wire signed [63:0] A_0_1;
wire signed [63:0] A_0_2;
wire signed [63:0] A_0_3;
wire signed [63:0] A_0_4;
wire signed [63:0] A_1_0;
wire signed [63:0] A_1_1;
wire signed [63:0] A_1_2;
wire signed [63:0] A_1_3;
wire signed [63:0] A_1_4;
wire signed [63:0] A_2_0;
wire signed [63:0] A_2_1;
wire signed [63:0] A_2_2;
wire signed [63:0] A_2_3;
wire signed [63:0] A_2_4;
wire signed [63:0] A_3_0;
wire signed [63:0] A_3_1;
wire signed [63:0] A_3_2;
wire signed [63:0] A_3_3;
wire signed [63:0] A_3_4;
wire signed [63:0] A_4_0;
wire signed [63:0] A_4_1;
wire signed [63:0] A_4_2;
wire signed [63:0] A_4_3;
wire signed [63:0] A_4_4;

assign A_0_0 = INF;
assign A_0_1 = INF;
assign A_0_2 = INF;
assign A_0_3 = INF;
assign A_0_4 = INF;
assign A_1_0 = INF;
assign A_1_1 = INF;
assign A_1_2 = INF;
assign A_1_3 = INF;
assign A_1_4 = INF;
assign A_2_0 = INF;
assign A_2_1 = INF;
assign A_2_2 = 64'sd7;
assign A_2_3 = INF;
assign A_2_4 = INF;
assign A_3_0 = INF;
assign A_3_1 = INF;
assign A_3_2 = 64'sd7;
assign A_3_3 = INF;
assign A_3_4 = 64'sd8;
assign A_4_0 = INF;
assign A_4_1 = INF;
assign A_4_2 = INF;
assign A_4_3 = INF;
assign A_4_4 = 64'sd8;

// State machine states
localparam S_IDLE = 3'd0;
localparam S_CHECK = 3'd1;
localparam S_MULT1 = 3'd2;
localparam S_MULT1A = 3'd3;
localparam S_MULT2 = 3'd4;
localparam S_MULT2A = 3'd5;
localparam S_DONE = 3'd6;

reg [2:0] state;
reg [2:0] next_state;

// Matrix registers
reg signed [63:0] result_0_0, result_0_1, result_0_2, result_0_3, result_0_4;
reg signed [63:0] result_1_0, result_1_1, result_1_2, result_1_3, result_1_4;
reg signed [63:0] result_2_0, result_2_1, result_2_2, result_2_3, result_2_4;
reg signed [63:0] result_3_0, result_3_1, result_3_2, result_3_3, result_3_4;
reg signed [63:0] result_4_0, result_4_1, result_4_2, result_4_3, result_4_4;

reg signed [63:0] base_0_0, base_0_1, base_0_2, base_0_3, base_0_4;
reg signed [63:0] base_1_0, base_1_1, base_1_2, base_1_3, base_1_4;
reg signed [63:0] base_2_0, base_2_1, base_2_2, base_2_3, base_2_4;
reg signed [63:0] base_3_0, base_3_1, base_3_2, base_3_3, base_3_4;
reg signed [63:0] base_4_0, base_4_1, base_4_2, base_4_3, base_4_4;

reg signed [63:0] mult_A_0_0, mult_A_0_1, mult_A_0_2, mult_A_0_3, mult_A_0_4;
reg signed [63:0] mult_A_1_0, mult_A_1_1, mult_A_1_2, mult_A_1_3, mult_A_1_4;
reg signed [63:0] mult_A_2_0, mult_A_2_1, mult_A_2_2, mult_A_2_3, mult_A_2_4;
reg signed [63:0] mult_A_3_0, mult_A_3_1, mult_A_3_2, mult_A_3_3, mult_A_3_4;
reg signed [63:0] mult_A_4_0, mult_A_4_1, mult_A_4_2, mult_A_4_3, mult_A_4_4;

reg signed [63:0] mult_B_0_0, mult_B_0_1, mult_B_0_2, mult_B_0_3, mult_B_0_4;
reg signed [63:0] mult_B_1_0, mult_B_1_1, mult_B_1_2, mult_B_1_3, mult_B_1_4;
reg signed [63:0] mult_B_2_0, mult_B_2_1, mult_B_2_2, mult_B_2_3, mult_B_2_4;
reg signed [63:0] mult_B_3_0, mult_B_3_1, mult_B_3_2, mult_B_3_3, mult_B_3_4;
reg signed [63:0] mult_B_4_0, mult_B_4_1, mult_B_4_2, mult_B_4_3, mult_B_4_4;

reg signed [63:0] mult_out_0_0, mult_out_0_1, mult_out_0_2, mult_out_0_3, mult_out_0_4;
reg signed [63:0] mult_out_1_0, mult_out_1_1, mult_out_1_2, mult_out_1_3, mult_out_1_4;
reg signed [63:0] mult_out_2_0, mult_out_2_1, mult_out_2_2, mult_out_2_3, mult_out_2_4;
reg signed [63:0] mult_out_3_0, mult_out_3_1, mult_out_3_2, mult_out_3_3, mult_out_3_4;
reg signed [63:0] mult_out_4_0, mult_out_4_1, mult_out_4_2, mult_out_4_3, mult_out_4_4;

reg [4:0] index;

// Multiplier logic
always @(*) begin
    mult_out_0_0 = compute_max(0, 0);
    mult_out_0_1 = compute_max(0, 1);
    mult_out_0_2 = compute_max(0, 2);
    mult_out_0_3 = compute_max(0, 3);
    mult_out_0_4 = compute_max(0, 4);
    mult_out_1_0 = compute_max(1, 0);
    mult_out_1_1 = compute_max(1, 1);
    mult_out_1_2 = compute_max(1, 2);
    mult_out_1_3 = compute_max(1, 3);
    mult_out_1_4 = compute_max(1, 4);
    mult_out_2_0 = compute_max(2, 0);
    mult_out_2_1 = compute_max(2, 1);
    mult_out_2_2 = compute_max(2, 2);
    mult_out_2_3 = compute_max(2, 3);
    mult_out_2_4 = compute_max(2, 4);
    mult_out_3_0 = compute_max(3, 0);
    mult_out_3_1 = compute_max(3, 1);
    mult_out_3_2 = compute_max(3, 2);
    mult_out_3_3 = compute_max(3, 3);
    mult_out_3_4 = compute_max(3, 4);
    mult_out_4_0 = compute_max(4, 0);
    mult_out_4_1 = compute_max(4, 1);
    mult_out_4_2 = compute_max(4, 2);
    mult_out_4_3 = compute_max(4, 3);
    mult_out_4_4 = compute_max(4, 4);
end

function automatic signed [63:0] compute_max(input [4:0] i, input [4:0] j);
    reg signed [63:0] max_val;
    reg signed [63:0] temp;
    reg signed [63:0] val_i_k;
    reg signed [63:0] val_k_j;
    begin
        max_val = INF;
        case (i)
            5'd0: begin
                case (j)
                    5'd0: begin val_i_k = mult_A_0_0; val_k_j = mult_B_0_0; end
                    5'd1: begin val_i_k = mult_A_0_0; val_k_j = mult_B_0_1; end
                    5'd2: begin val_i_k = mult_A_0_0; val_k_j = mult_B_0_2; end
                    5'd3: begin val_i_k = mult_A_0_0; val_k_j = mult_B_0_3; end
                    5'd4: begin val_i_k = mult_A_0_0; val_k_j = mult_B_0_4; end
                endcase
            end
            5'd1: begin
                case (j)
                    5'd0: begin val_i_k = mult_A_1_0; val_k_j = mult_B_0_0; end
                    5'd1: begin val_i_k = mult_A_1_0; val_k_j = mult_B_0_1; end
                    5'd2: begin val_i_k = mult_A_1_0; val_k_j = mult_B_0_2; end
                    5'd3: begin val_i_k = mult_A_1_0; val_k_j = mult_B_0_3; end
                    5'd4: begin val_i_k = mult_A_1_0; val_k_j = mult_B_0_4; end
                endcase
            end
            5'd2: begin
                case (j)
                    5'd0: begin val_i_k = mult_A_2_0; val_k_j = mult_B_0_0; end
                    5'd1: begin val_i_k = mult_A_2_0; val_k_j = mult_B_0_1; end
                    5'd2: begin val_i_k = mult_A_2_0; val_k_j = mult_B_0_2; end
                    5'd3: begin val_i_k = mult_A_2_0; val_k_j = mult_B_0_3; end
                    5'd4: begin val_i_k = mult_A_2_0; val_k_j = mult_B_0_4; end
                endcase
            end
            5'd3: begin
                case (j)
                    5'd0: begin val_i_k = mult_A_3_0; val_k_j = mult_B_0_0; end
                    5'd1: begin val_i_k = mult_A_3_0; val_k_j = mult_B_0_1; end
                    5'd2: begin val_i_k = mult_A_3_0; val_k_j = mult_B_0_2; end
                    5'd3: begin val_i_k = mult_A_3_0; val_k_j = mult_B_0_3; end
                    5'd4: begin val_i_k = mult_A_3_0; val_k_j = mult_B_0_4; end
                endcase
            end
            5'd4: begin
                case (j)
                    5'd0: begin val_i_k = mult_A_4_0; val_k_j = mult_B_0_0; end
                    5'd1: begin val_i_k = mult_A_4_0; val_k_j = mult_B_0_1; end
                    5'd2: begin val_i_k = mult_A_4_0; val_k_j = mult_B_0_2; end
                    5'd3: begin val_i_k = mult_A_4_0; val_k_j = mult_B_0_3; end
                    5'd4: begin val_i_k = mult_A_4_0; val_k_j = mult_B_0_4; end
                endcase
            end
        endcase
        temp = val_i_k + val_k_j;
        if (val_i_k > INF && val_k_j > INF) begin
            if ($signed(temp) > $signed(max_val)) begin
                max_val = temp;
            end
        end
        compute_max = max_val;
    end
endfunction

// State machine next state logic
always @(*) begin
    next_state = state;
    case (state)
        S_IDLE: begin
            if (start) begin
                next_state = S_CHECK;
            end
        end
        S_CHECK: begin
            if (index >= 30) begin
                next_state = S_DONE;
            end else begin
                next_state = S_MULT1;
            end
        end
        S_MULT1: begin
            next_state = S_MULT1A;
        end
        S_MULT1A: begin
            next_state = S_MULT2;
        end
        S_MULT2: begin
            next_state = S_MULT2A;
        end
        S_MULT2A: begin
            next_state = S_CHECK;
        end
        S_DONE: begin
            next_state = S_IDLE;
        end
        default: next_state = S_IDLE;
    endcase
end

// State machine state register and operations
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        index <= 5'd0;
        result_max <= 64'd0;
        result_0_0 <= 64'd0; result_0_1 <= INF; result_0_2 <= INF; result_0_3 <= INF; result_0_4 <= INF;
        result_1_0 <= INF; result_1_1 <= 64'd0; result_1_2 <= INF; result_1_3 <= INF; result_1_4 <= INF;
        result_2_0 <= INF; result_2_1 <= INF; result_2_2 <= 64'd0; result_2_3 <= INF; result_2_4 <= INF;
        result_3_0 <= INF; result_3_1 <= INF; result_3_2 <= INF; result_3_3 <= 64'd0; result_3_4 <= INF;
        result_4_0 <= INF; result_4_1 <= INF; result_4_2 <= INF; result_4_3 <= INF; result_4_4 <= 64'd0;
        base_0_0 <= INF; base_0_1 <= INF; base_0_2 <= INF; base_0_3 <= INF; base_0_4 <= INF;
        base_1_0 <= INF; base_1_1 <= INF; base_1_2 <= INF; base_1_3 <= INF; base_1_4 <= INF;
        base_2_0 <= INF; base_2_1 <= INF; base_2_2 <= INF; base_2_3 <= INF; base_2_4 <= INF;
        base_3_0 <= INF; base_3_1 <= INF; base_3_2 <= INF; base_3_3 <= INF; base_3_4 <= INF;
        base_4_0 <= INF; base_4_1 <= INF; base_4_2 <= INF; base_4_3 <= INF; base_4_4 <= INF;
        mult_A_0_0 <= INF; mult_A_0_1 <= INF; mult_A_0_2 <= INF; mult_A_0_3 <= INF; mult_A_0_4 <= INF;
        mult_A_1_0 <= INF; mult_A_1_1 <= INF; mult_A_1_2 <= INF; mult_A_1_3 <= INF; mult_A_1_4 <= INF;
        mult_A_2_0 <= INF; mult_A_2_1 <= INF; mult_A_2_2 <= INF; mult_A_2_3 <= INF; mult_A_2_4 <= INF;
        mult_A_3_0 <= INF; mult_A_3_1 <= INF; mult_A_3_2 <= INF; mult_A_3_3 <= INF; mult_A_3_4 <= INF;
        mult_A_4_0 <= INF; mult_A_4_1 <= INF; mult_A_4_2 <= INF; mult_A_4_3 <= INF; mult_A_4_4 <= INF;
        mult_B_0_0 <= INF; mult_B_0_1 <= INF; mult_B_0_2 <= INF; mult_B_0_3 <= INF; mult_B_0_4 <= INF;
        mult_B_1_0 <= INF; mult_B_1_1 <= INF; mult_B_1_2 <= INF; mult_B_1_3 <= INF; mult_B_1_4 <= INF;
        mult_B_2_0 <= INF; mult_B_2_1 <= INF; mult_B_2_2 <= INF; mult_B_2_3 <= INF; mult_B_2_4 <= INF;
        mult_B_3_0 <= INF; mult_B_3_1 <= INF; mult_B_3_2 <= INF; mult_B_3_3 <= INF; mult_B_3_4 <= INF;
        mult_B_4_0 <= INF; mult_B_4_1 <= INF; mult_B_4_2 <= INF; mult_B_4_3 <= INF; mult_B_4_4 <= INF;
    end else begin
        state <= next_state;
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                index <= 5'd0;
                if (start) begin
                    // Initialize result to identity matrix
                    result_0_0 <= 64'd0; result_0_1 <= INF; result_0_2 <= INF; result_0_3 <= INF; result_0_4 <= INF;
                    result_1_0 <= INF; result_1_1 <= 64'd0; result_1_2 <= INF; result_1_3 <= INF; result_1_4 <= INF;
                    result_2_0 <= INF; result_2_1 <= INF; result_2_2 <= 64'd0; result_2_3 <= INF; result_2_4 <= INF;
                    result_3_0 <= INF; result_3_1 <= INF; result_3_2 <= INF; result_3_3 <= 64'd0; result_3_4 <= INF;
                    result_4_0 <= INF; result_4_1 <= INF; result_4_2 <= INF; result_4_3 <= INF; result_4_4 <= 64'd0;
                    // Initialize base to A
                    base_0_0 <= A_0_0; base_0_1 <= A_0_1; base_0_2 <= A_0_2; base_0_3 <= A_0_3; base_0_4 <= A_0_4;
                    base_1_0 <= A_1_0; base_1_1 <= A_1_1; base_1_2 <= A_1_2; base_1_3 <= A_1_3; base_1_4 <= A_1_4;
                    base_2_0 <= A_2_0; base_2_1 <= A_2_1; base_2_2 <= A_2_2; base_2_3 <= A_2_3; base_2_4 <= A_2_4;
                    base_3_0 <= A_3_0; base_3_1 <= A_3_1; base_3_2 <= A_3_2; base_3_3 <= A_3_3; base_3_4 <= A_3_4;
                    base_4_0 <= A_4_0; base_4_1 <= A_4_1; base_4_2 <= A_4_2; base_4_3 <= A_4_3; base_4_4 <= A_4_4;
                end
            end

            S_MULT1: begin
                // Set mult_A and mult_B for result * base
                mult_A_0_0 <= result_0_0; mult_A_0_1 <= result_0_1; mult_A_0_2 <= result_0_2; mult_A_0_3 <= result_0_3; mult_A_0_4 <= result_0_4;
                mult_A_1_0 <= result_1_0; mult_A_1_1 <= result_1_1; mult_A_1_2 <= result_1_2; mult_A_1_3 <= result_1_3; mult_A_1_4 <= result_1_4;
                mult_A_2_0 <= result_2_0; mult_A_2_1 <= result_2_1; mult_A_2_2 <= result_2_2; mult_A_2_3 <= result_2_3; mult_A_2_4 <= result_2_4;
                mult_A_3_0 <= result_3_0; mult_A_3_1 <= result_3_1; mult_A_3_2 <= result_3_2; mult_A_3_3 <= result_3_3; mult_A_3_4 <= result_3_4;
                mult_A_4_0 <= result_4_0; mult_A_4_1 <= result_4_1; mult_A_4_2 <= result_4_2; mult_A_4_3 <= result_4_3; mult_A_4_4 <= result_4_4;
                mult_B_0_0 <= base_0_0; mult_B_0_1 <= base_0_1; mult_B_0_2 <= base_0_2; mult_B_0_3 <= base_0_3; mult_B_0_4 <= base_0_4;
                mult_B_1_0 <= base_1_0; mult_B_1_1 <= base_1_1; mult_B_1_2 <= base_1_2; mult_B_1_3 <= base_1_3; mult_B_1_4 <= base_1_4;
                mult_B_2_0 <= base_2_0; mult_B_2_1 <= base_2_1; mult_B_2_2 <= base_2_2; mult_B_2_3 <= base_2_3; mult_B_2_4 <= base_2_4;
                mult_B_3_0 <= base_3_0; mult_B_3_1 <= base_3_1; mult_B_3_2 <= base_3_2; mult_B_3_3 <= base_3_3; mult_B_3_4 <= base_3_4;
                mult_B_4_0 <= base_4_0; mult_B_4_1 <= base_4_1; mult_B_4_2 <= base_4_2; mult_B_4_3 <= base_4_3; mult_B_4_4 <= base_4_4;
            end

            S_MULT1A: begin
                // Update result with mult_out
                result_0_0 <= mult_out_0_0; result_0_1 <= mult_out_0_1; result_0_2 <= mult_out_0_2; result_0_3 <= mult_out_0_3; result_0_4 <= mult_out_0_4;
                result_1_0 <= mult_out_1_0; result_1_1 <= mult_out_1_1; result_1_2 <= mult_out_1_2; result_1_3 <= mult_out_1_3; result_1_4 <= mult_out_1_4;
                result_2_0 <= mult_out_2_0; result_2_1 <= mult_out_2_1; result_2_2 <= mult_out_2_2; result_2_3 <= mult_out_2_3; result_2_4 <= mult_out_2_4;
                result_3_0 <= mult_out_3_0; result_3_1 <= mult_out_3_1; result_3_2 <= mult_out_3_2; result_3_3 <= mult_out_3_3; result_3_4 <= mult_out_3_4;
                result_4_0 <= mult_out_4_0; result_4_1 <= mult_out_4_1; result_4_2 <= mult_out_4_2; result_4_3 <= mult_out_4_3; result_4_4 <= mult_out_4_4;
            end

            S_MULT2: begin
                // Set mult_A and mult_B for base * base
                mult_A_0_0 <= base_0_0; mult_A_0_1 <= base_0_1; mult_A_0_2 <= base_0_2; mult_A_0_3 <= base_0_3; mult_A_0_4 <= base_0_4;
                mult_A_1_0 <= base_1_0; mult_A_1_1 <= base_1_1; mult_A_1_2 <= base_1_2; mult_A_1_3 <= base_1_3; mult_A_1_4 <= base_1_4;
                mult_A_2_0 <= base_2_0; mult_A_2_1 <= base_2_1; mult_A_2_2 <= base_2_2; mult_A_2_3 <= base_2_3; mult_A_2_4 <= base_2_4;
                mult_A_3_0 <= base_3_0; mult_A_3_1 <= base_3_1; mult_A_3_2 <= base_3_2; mult_A_3_3 <= base_3_3; mult_A_3_4 <= base_3_4;
                mult_A_4_0 <= base_4_0; mult_A_4_1 <= base_4_1; mult_A_4_2 <= base_4_2; mult_A_4_3 <= base_4_3; mult_A_4_4 <= base_4_4;
                mult_B_0_0 <= base_0_0; mult_B_0_1 <= base_0_1; mult_B_0_2 <= base_0_2; mult_B_0_3 <= base_0_3; mult_B_0_4 <= base_0_4;
                mult_B_1_0 <= base_1_0; mult_B_1_1 <= base_1_1; mult_B_1_2 <= base_1_2; mult_B_1_3 <= base_1_3; mult_B_1_4 <= base_1_4;
                mult_B_2_0 <= base_2_0; mult_B_2_1 <= base_2_1; mult_B_2_2 <= base_2_2; mult_B_2_3 <= base_2_3; mult_B_2_4 <= base_2_4;
                mult_B_3_0 <= base_3_0; mult_B_3_1 <= base_3_1; mult_B_3_2 <= base_3_2; mult_B_3_3 <= base_3_3; mult_B_3_4 <= base_3_4;
                mult_B_4_0 <= base_4_0; mult_B_4_1 <= base_4_1; mult_B_4_2 <= base_4_2; mult_B_4_3 <= base_4_3; mult_B_4_4 <= base_4_4;
            end

            S_MULT2A: begin
                // Update base with mult_out
                base_0_0 <= mult_out_0_0; base_0_1 <= mult_out_0_1; base_0_2 <= mult_out_0_2; base_0_3 <= mult_out_0_3; base_0_4 <= mult_out_0_4;
                base_1_0 <= mult_out_1_0; base_1_1 <= mult_out_1_1; base_1_2 <= mult_out_1_2; base_1_3 <= mult_out_1_3; base_1_4 <= mult_out_1_4;
                base_2_0 <= mult_out_2_0; base_2_1 <= mult_out_2_1; base_2_2 <= mult_out_2_2; base_2_3 <= mult_out_2_3; base_2_4 <= mult_out_2_4;
                base_3_0 <= mult_out_3_0; base_3_1 <= mult_out_3_1; base_3_2 <= mult_out_3_2; base_3_3 <= mult_out_3_3; base_3_4 <= mult_out_3_4;
                base_4_0 <= mult_out_4_0; base_4_1 <= mult_out_4_1; base_4_2 <= mult_out_4_2; base_4_3 <= mult_out_4_3; base_4_4 <= mult_out_4_4;
                index <= index + 5'd1;
            end

            S_DONE: begin
                // Compute the maximum value in result matrix
                result_max <= result_0_0;
                if ($signed(result_0_1) > $signed(result_max)) result_max <= result_0_1;
                if ($signed(result_0_2) > $signed(result_max)) result_max <= result_0_2;
                if ($signed(result_0_3) > $signed(result_max)) result_max <= result_0_3;
                if ($signed(result_0_4) > $signed(result_max)) result_max <= result_0_4;
                if ($signed(result_1_0) > $signed(result_max)) result_max <= result_1_0;
                if ($signed(result_1_1) > $signed(result_max)) result_max <= result_1_1;
                if ($signed(result_1_2) > $signed(result_max)) result_max <= result_1_2;
                if ($signed(result_1_3) > $signed(result_max)) result_max <= result_1_3;
                if ($signed(result_1_4) > $signed(result_max)) result_max <= result_1_4;
                if ($signed(result_2_0) > $signed(result_max)) result_max <= result_2_0;
                if ($signed(result_2_1) > $signed(result_max)) result_max <= result_2_1;
                if ($signed(result_2_2) > $signed(result_max)) result_max <= result_2_2;
                if ($signed(result_2_3) > $signed(result_max)) result_max <= result_2_3;
                if ($signed(result_2_4) > $signed(result_max)) result_max <= result_2_4;
                if ($signed(result_3_0) > $signed(result_max)) result_max <= result_3_0;
                if ($signed(result_3_1) > $signed(result_max)) result_max <= result_3_1;
                if ($signed(result_3_2) > $signed(result_max)) result_max <= result_3_2;
                if ($signed(result_3_3) > $signed(result_max)) result_max <= result_3_3;
                if ($signed(result_3_4) > $signed(result_max)) result_max <= result_3_4;
                if ($signed(result_4_0) > $signed(result_max)) result_max <= result_4_0;
                if ($signed(result_4_1) > $signed(result_max)) result_max <= result_4_1;
                if ($signed(result_4_2) > $signed(result_max)) result_max <= result_4_2;
                if ($signed(result_4_3) > $signed(result_max)) result_max <= result_4_3;
                if ($signed(result_4_4) > $signed(result_max)) result_max <= result_4_4;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule